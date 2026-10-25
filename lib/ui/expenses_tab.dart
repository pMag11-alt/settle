import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/model.dart';
import 'expense_editor.dart';
import 'scope.dart';
import 'widgets.dart';

class ExpensesTab extends StatelessWidget {
  const ExpensesTab({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final g = group;
    if (g.expenses.isEmpty && g.payments.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No expenses yet',
        message: 'Add the first one: who paid, how much, and who it was for.',
      );
    }
    // Expenses and payments, newest first, under date headings.
    final items = <(DateTime, Object)>[for (final e in g.expenses) (e.date, e), for (final p in g.payments) (p.date, p)]
      ..sort((a, b) => b.$1.compareTo(a.$1));
    final children = <Widget>[_TotalsHeader(group: g)];
    DateTime? lastDay;
    for (final (date, item) in items) {
      final day = DateTime(date.year, date.month, date.day);
      if (day != lastDay) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              DateFormat('EEEE, d MMMM').format(day),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        );
        lastDay = day;
      }
      children.add(
        item is Expense ? _ExpenseTile(group: g, expense: item) : _PaymentTile(group: g, payment: item as Payment),
      );
    }
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: children);
  }
}

class _TotalsHeader extends StatelessWidget {
  const _TotalsHeader({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total spent',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.currency.format(group.totalSpent),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${group.expenses.length} expenses',
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final m in group.members.take(5))
                      Padding(padding: const EdgeInsets.only(left: 2), child: MemberAvatar(m, radius: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.group, required this.expense});

  final Group group;
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = expense;
    final n = e.split.participants.length;
    final splitText = switch (e.split.mode) {
      SplitMode.equal => n == group.members.length ? 'split equally' : 'split $n ways',
      SplitMode.exact => 'exact amounts',
      SplitMode.percent => 'by percentage',
      SplitMode.shares => 'by shares',
    };
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) async {
        final state = AppScope.read(context);
        final messenger = ScaffoldMessenger.of(context);
        await state.deleteExpense(group.id, e.id);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Deleted “${e.description}”'),
              action: SnackBarAction(label: 'Undo', onPressed: () => state.undo(group.id)),
            ),
          );
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: categoryColor(e.category).withValues(alpha: 0.15),
          child: Icon(categoryIcon(e.category), color: categoryColor(e.category)),
        ),
        title: Text(e.description, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${group.member(e.paidBy).name} paid · $splitText'),
        trailing: Text(group.currency.format(e.amount), style: theme.textTheme.titleSmall),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => ExpenseEditor(groupId: group.id, expense: e),
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.group, required this.payment});

  final Group group;
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = payment;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: positiveColor(context).withValues(alpha: 0.15),
        child: Icon(Icons.handshake_outlined, color: positiveColor(context)),
      ),
      title: Text('${group.member(p.from).name} paid ${group.member(p.to).name}'),
      subtitle: const Text('Settlement'),
      trailing: Text(
        group.currency.format(p.amount),
        style: theme.textTheme.titleSmall?.copyWith(color: positiveColor(context)),
      ),
      onLongPress: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Remove this payment?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
            ],
          ),
        );
        if (ok == true && context.mounted) await AppScope.read(context).deletePayment(group.id, p.id);
      },
    );
  }
}
