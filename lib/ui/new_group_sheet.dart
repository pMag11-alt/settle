import 'package:flutter/material.dart';

import '../domain/money.dart';
import 'scope.dart';

const groupEmojis = ['🏖️', '🏠', '✈️', '🍕', '🎉', '🏕️', '💼', '🎓', '🚗', '⚽'];

/// Asks for a name, emoji, currency and members; returns the new group id.
Future<String?> showNewGroupSheet(BuildContext context) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _NewGroupSheet(),
);

class _NewGroupSheet extends StatefulWidget {
  const _NewGroupSheet();

  @override
  State<_NewGroupSheet> createState() => _NewGroupSheetState();
}

class _NewGroupSheetState extends State<_NewGroupSheet> {
  final _name = TextEditingController();
  final _member = TextEditingController();
  final _members = <String>[];
  String _emoji = groupEmojis.first;
  String _currency = 'INR';

  void _addMember() {
    final name = _member.text.trim();
    if (name.isEmpty || _members.any((m) => m.toLowerCase() == name.toLowerCase())) return;
    setState(() {
      _members.add(name);
      _member.clear();
    });
  }

  bool get _valid => _name.text.trim().isNotEmpty && _members.length >= 2;

  Future<void> _create() async {
    _addMember();
    if (!_valid) return;
    final id = await AppScope.read(
      context,
    ).createGroup(name: _name.text.trim(), emoji: _emoji, currency: _currency, memberNames: _members);
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New group', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'Goa trip, Flat 4B, …'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final e in groupEmojis)
                  ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 20)),
                    selected: e == _emoji,
                    onSelected: (_) => setState(() => _emoji = e),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _currency,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: [
                for (final c in currencies)
                  DropdownMenuItem(
                    value: c.code,
                    child: Text('${c.code} · ${c.name}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _currency = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _member,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Add people',
                hintText: 'A name, then Enter',
                suffixIcon: IconButton(icon: const Icon(Icons.person_add_alt), onPressed: _addMember),
              ),
              onSubmitted: (_) => _addMember(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in _members)
                  InputChip(label: Text(m), onDeleted: () => setState(() => _members.remove(m))),
              ],
            ),
            if (_members.length < 2)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Add at least two people.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _valid ? _create : null, child: const Text('Create group')),
          ],
        ),
      ),
    );
  }
}
