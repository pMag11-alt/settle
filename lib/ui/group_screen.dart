import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/insights.dart';
import '../domain/model.dart';
import '../domain/settle.dart';
import 'activity_screen.dart';
import 'balances_tab.dart';
import 'expense_editor.dart';
import 'expenses_tab.dart';
import 'insights_tab.dart';
import 'members_screen.dart';
import 'new_group_sheet.dart';
import 'scope.dart';

enum _Action { members, activity, summary, csv, rename, delete }

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key, required this.groupId, this.initialTab = 0});

  final String groupId;
  final int initialTab;

  Future<void> _addExpense(BuildContext context, Group g) => Navigator.of(
    context,
  ).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => ExpenseEditor(groupId: g.id)));

  Future<void> _undo(BuildContext context) async {
    final state = AppScope.read(context);
    final g = state.group(groupId)!;
    final last = state.log(groupId).events.last;
    final what = last.describe(g);
    await state.undo(groupId);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Undid: $what')));
    }
  }

  Future<void> _onAction(BuildContext context, Group g, _Action a) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    switch (a) {
      case _Action.members:
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MembersScreen(groupId: g.id)));
      case _Action.activity:
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActivityScreen(groupId: g.id)));
      case _Action.summary:
        await Clipboard.setData(ClipboardData(text: summaryText(g)));
        messenger.showSnackBar(const SnackBar(content: Text('Summary copied: paste it into your group chat')));
      case _Action.csv:
        if (context.mounted) await _showCsv(context, g);
      case _Action.rename:
        if (context.mounted) await _rename(context, g);
      case _Action.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text('Delete “${g.name}”?'),
            content: const Text('Every expense and payment in it will be gone. This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          Navigator.of(context).pop();
          await state.deleteGroup(g.id);
        }
    }
  }

  Future<void> _showCsv(BuildContext context, Group g) {
    final csv = exportCsv(g);
    return showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Export as CSV'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csv));
              if (c.mounted) Navigator.pop(c);
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, Group g) async {
    final name = TextEditingController(text: g.name);
    var emoji = g.emoji;
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: const Text('Rename group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                children: [
                  for (final e in groupEmojis)
                    ChoiceChip(label: Text(e), selected: e == emoji, onSelected: (_) => setState(() => emoji = e)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (result == true && name.text.trim().isNotEmpty && context.mounted) {
      await AppScope.read(context).renameGroup(g.id, name.text.trim(), emoji);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = state.group(groupId);
    if (g == null) return const Scaffold(); // deleted while open
    final canUndo = state.log(groupId).events.length > 1;
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${g.emoji}  ${g.name}'),
          actions: [
            IconButton(
              tooltip: 'Undo the last change',
              icon: const Icon(Icons.undo),
              onPressed: canUndo ? () => _undo(context) : null,
            ),
            PopupMenuButton<_Action>(
              onSelected: (a) => _onAction(context, g, a),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _Action.members,
                  child: ListTile(leading: Icon(Icons.group_outlined), title: Text('People')),
                ),
                PopupMenuItem(
                  value: _Action.activity,
                  child: ListTile(leading: Icon(Icons.history), title: Text('Activity')),
                ),
                PopupMenuItem(
                  value: _Action.summary,
                  child: ListTile(leading: Icon(Icons.chat_outlined), title: Text('Copy summary')),
                ),
                PopupMenuItem(
                  value: _Action.csv,
                  child: ListTile(leading: Icon(Icons.table_view_outlined), title: Text('Export CSV')),
                ),
                PopupMenuItem(
                  value: _Action.rename,
                  child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Rename')),
                ),
                PopupMenuItem(
                  value: _Action.delete,
                  child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete group')),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Expenses'),
              Tab(text: 'Balances'),
              Tab(text: 'Insights'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ExpensesTab(group: g),
            BalancesTab(group: g),
            InsightsTab(group: g),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addExpense(context, g),
          icon: const Icon(Icons.add),
          label: const Text('Add expense'),
        ),
      ),
    );
  }
}

/// A plain-text recap to paste into a chat.
String summaryText(Group g) {
  final c = g.currency;
  final b = balances(g);
  final plan = settleOptimal(b);
  final lines = <String>[
    '${g.emoji} ${g.name}: ${c.format(g.totalSpent)} spent over ${g.expenses.length} expenses',
    '',
  ];
  if (plan.isEmpty) {
    lines.add('Everyone is settled up.');
  } else {
    lines.add('To settle up (${plan.length} payment${plan.length == 1 ? '' : 's'}):');
    for (final t in plan) {
      lines.add('• ${g.member(t.from).name} pays ${g.member(t.to).name} ${c.format(t.amount)}');
    }
  }
  return lines.join('\n');
}
