import 'package:flutter/material.dart' hide Split;
import 'package:intl/intl.dart';

import '../domain/events.dart';
import '../domain/model.dart';
import '../domain/money.dart';
import 'scope.dart';
import 'widgets.dart';

/// Adds a new expense, or edits [expense] when given.
class ExpenseEditor extends StatefulWidget {
  const ExpenseEditor({super.key, required this.groupId, this.expense});

  final String groupId;
  final Expense? expense;

  @override
  State<ExpenseEditor> createState() => _ExpenseEditorState();
}

/// Parses "33.33" into 3333 (two implied decimals) without doubles.
int? parseBasisPoints(String text) {
  final m = RegExp(r'^\s*(\d{0,3})(?:\.(\d{0,2}))?\s*$').firstMatch(text);
  if (m == null || (m.group(1)!.isEmpty && (m.group(2) ?? '').isEmpty)) return null;
  final whole = m.group(1)!.isEmpty ? 0 : int.parse(m.group(1)!);
  final frac = (m.group(2) ?? '').padRight(2, '0');
  return whole * 100 + int.parse(frac);
}

String formatBasisPoints(int bp) => bp % 100 == 0 ? '${bp ~/ 100}' : (bp / 100).toStringAsFixed(2);

class _ExpenseEditorState extends State<ExpenseEditor> {
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  late Category _category;
  late String _paidBy;
  late DateTime _date;
  late SplitMode _mode;
  final Set<String> _equal = {};
  final Map<String, TextEditingController> _exact = {};
  final Map<String, TextEditingController> _percent = {};
  final Map<String, int> _shares = {};
  bool _triedSave = false;

  @override
  void initState() {
    super.initState();
    final g = AppScope.read(context).group(widget.groupId)!;
    final e = widget.expense;
    final c = g.currency;
    _amount = TextEditingController(text: e == null ? '' : c.plain(e.amount));
    _description = TextEditingController(text: e?.description ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? Category.food;
    _paidBy = e?.paidBy ?? g.members.first.id;
    _date = e?.date ?? DateTime.now();
    _mode = e?.split.mode ?? SplitMode.equal;
    for (final m in g.members) {
      final v = e?.split.values[m.id] ?? 0;
      final inSplit = e == null || v > 0;
      if (inSplit) _equal.add(m.id);
      _exact[m.id] = TextEditingController(text: e?.split.mode == SplitMode.exact && v > 0 ? c.plain(v) : '');
      _percent[m.id] = TextEditingController(
        text: e?.split.mode == SplitMode.percent && v > 0 ? formatBasisPoints(v) : '',
      );
      _shares[m.id] = e?.split.mode == SplitMode.shares ? v : (inSplit ? 1 : 0);
    }
  }

  @override
  void dispose() {
    for (final c in [_amount, _description, _notes, ..._exact.values, ..._percent.values]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Switching to exact amounts or percentages starts from an even split
  /// of the people currently included, rather than empty boxes.
  void _switchMode(SplitMode mode) {
    _mode = mode;
    final ids = [
      for (final id in _exact.keys)
        if (_equal.contains(id)) id,
    ];
    if (ids.isEmpty) return;
    final c = _currency;
    if (mode == SplitMode.exact && _exact.values.every((t) => t.text.isEmpty) && _total != null) {
      final parts = allocate(_total!, [for (final _ in ids) 1]);
      for (var i = 0; i < ids.length; i++) {
        _exact[ids[i]]!.text = c.plain(parts[i]);
      }
    }
    if (mode == SplitMode.percent && _percent.values.every((t) => t.text.isEmpty)) {
      final parts = allocate(10000, [for (final _ in ids) 1]);
      for (var i = 0; i < ids.length; i++) {
        _percent[ids[i]]!.text = formatBasisPoints(parts[i]);
      }
    }
    if (mode == SplitMode.shares && _shares.values.every((v) => v == 0)) {
      for (final id in ids) {
        _shares[id] = 1;
      }
    }
  }

  Split _split() => switch (_mode) {
    SplitMode.equal => Split(SplitMode.equal, {for (final id in _equal) id: 1}),
    SplitMode.exact => Split(SplitMode.exact, {
      for (final e in _exact.entries) e.key: _currency.parse(e.value.text) ?? 0,
    }),
    SplitMode.percent => Split(SplitMode.percent, {
      for (final e in _percent.entries) e.key: parseBasisPoints(e.value.text) ?? 0,
    }),
    SplitMode.shares => Split(SplitMode.shares, Map.of(_shares)),
  };

  Currency get _currency => AppScope.read(context).group(widget.groupId)!.currency;

  int? get _total {
    final v = _currency.parse(_amount.text);
    return v != null && v > 0 ? v : null;
  }

  Future<void> _save() async {
    setState(() => _triedSave = true);
    final total = _total;
    if (total == null || _description.text.trim().isEmpty) return;
    final split = _split();
    try {
      split.shares(total);
    } on SplitError {
      return;
    }
    final e = Expense(
      id: widget.expense?.id ?? newId(),
      description: _description.text.trim(),
      amount: total,
      paidBy: _paidBy,
      split: split,
      category: _category,
      date: _date,
      notes: _notes.text.trim(),
    );
    await AppScope.read(context).saveExpense(widget.groupId, e);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final e = widget.expense!;
    Navigator.of(context).pop();
    await state.deleteExpense(widget.groupId, e.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted “${e.description}”'),
        action: SnackBarAction(label: 'Undo', onPressed: () => state.undo(widget.groupId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context).group(widget.groupId)!;
    final c = g.currency;
    final theme = Theme.of(context);
    final total = _total;
    String? splitError;
    Map<String, int> preview = {};
    if (total != null) {
      try {
        preview = _split().shares(total);
      } on SplitError catch (e) {
        splitError = switch (_mode) {
          SplitMode.exact => () {
            final sum = _exact.values.fold<int>(0, (a, t) => a + (c.parse(t.text) ?? 0));
            final left = total - sum;
            return left > 0 ? '${c.format(left)} left to assign' : '${c.format(-left)} too much assigned';
          }(),
          SplitMode.percent => () {
            final sum = _percent.values.fold<int>(0, (a, t) => a + (parseBasisPoints(t.text) ?? 0));
            return 'Adds up to ${formatBasisPoints(sum)}%, not 100%';
          }(),
          _ => e.message,
        };
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Add expense' : 'Edit expense'),
        actions: [
          if (widget.expense != null)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(key: const Key('save'), onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            key: const Key('amount'),
            controller: _amount,
            autofocus: widget.expense == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.headlineMedium,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '${c.symbol} ',
              errorText: _triedSave && total == null ? 'Enter an amount like 450 or 99.50' : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('description'),
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'What was it for?',
              errorText: _triedSave && _description.text.trim().isEmpty ? 'Add a short description' : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final cat in Category.values)
                ChoiceChip(
                  avatar: Icon(categoryIcon(cat), size: 18),
                  label: Text(cat.label),
                  selected: cat == _category,
                  onSelected: (_) => setState(() => _category = cat),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('paidBy'),
                  initialValue: _paidBy,
                  decoration: const InputDecoration(labelText: 'Paid by'),
                  items: [
                    for (final m in g.members)
                      DropdownMenuItem(
                        value: m.id,
                        child: Row(
                          children: [
                            MemberAvatar(m, radius: 11),
                            const SizedBox(width: 8),
                            Flexible(child: Text(m.name, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _paidBy = v!),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: Text(DateFormat('d MMM y').format(_date)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Split', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<SplitMode>(
              segments: [for (final m in SplitMode.values) ButtonSegment(value: m, label: Text(m.label))],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _switchMode(s.first)),
            ),
          ),
          const SizedBox(height: 8),
          for (final m in g.members) _memberRow(m, c, preview[m.id]),
          if (splitError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(splitError, style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
        ],
      ),
    );
  }

  Widget _memberRow(Member m, Currency c, int? share) {
    final theme = Theme.of(context);
    final shareText = Text(
      share == null ? '' : c.format(share),
      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
    final Widget control = switch (_mode) {
      SplitMode.equal => Checkbox(
        value: _equal.contains(m.id),
        onChanged: (v) => setState(() => v! ? _equal.add(m.id) : _equal.remove(m.id)),
      ),
      SplitMode.exact => SizedBox(
        width: 120,
        child: TextField(
          controller: _exact[m.id],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.end,
          decoration: InputDecoration(isDense: true, prefixText: c.symbol),
          onChanged: (_) => setState(() {}),
        ),
      ),
      SplitMode.percent => SizedBox(
        width: 100,
        child: TextField(
          controller: _percent[m.id],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.end,
          decoration: const InputDecoration(isDense: true, suffixText: '%'),
          onChanged: (_) => setState(() {}),
        ),
      ),
      SplitMode.shares => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _shares[m.id]! > 0 ? () => setState(() => _shares[m.id] = _shares[m.id]! - 1) : null,
          ),
          SizedBox(width: 24, child: Text('${_shares[m.id]}', textAlign: TextAlign.center)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => setState(() => _shares[m.id] = _shares[m.id]! + 1),
          ),
        ],
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          MemberAvatar(m, radius: 16),
          const SizedBox(width: 12),
          Expanded(child: Text(m.name)),
          if (_mode != SplitMode.exact) shareText,
          const SizedBox(width: 8),
          control,
        ],
      ),
    );
  }
}
