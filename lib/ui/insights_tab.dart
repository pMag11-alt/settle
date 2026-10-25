import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/insights.dart';
import '../domain/model.dart';
import 'charts.dart';
import 'widgets.dart';

class InsightsTab extends StatelessWidget {
  const InsightsTab({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final c = g.currency;
    final theme = Theme.of(context);
    if (g.expenses.isEmpty) {
      return const EmptyState(
        icon: Icons.pie_chart_outline,
        title: 'Nothing to chart yet',
        message: 'Insights appear once the group has expenses.',
      );
    }
    final byCategory = spendingByCategory(g);
    final byMember = spendingByMember(g);
    final byMonth = spendingByMonth(g);
    final maxMember = byMember.fold<int>(1, (m, s) => [m, s.paid, s.consumed].reduce((a, b) => a > b ? a : b));
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: [
        Section(
          title: 'Where the money went',
          child: LayoutBuilder(
            builder: (context, box) {
              final chart = DonutChart(
                slices: [for (final (cat, v) in byCategory) DonutSlice(v, categoryColor(cat))],
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.format(g.totalSpent, compact: true), style: theme.textTheme.titleLarge),
                    Text('total', style: muted),
                  ],
                ),
              );
              final legend = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (cat, v) in byCategory)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(categoryIcon(cat), size: 18, color: categoryColor(cat)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(cat.label)),
                          Text(c.format(v)),
                          SizedBox(
                            width: 48,
                            child: Text('${(100 * v / g.totalSpent).round()}%', textAlign: TextAlign.end, style: muted),
                          ),
                        ],
                      ),
                    ),
                ],
              );
              if (box.maxWidth < 520) {
                return Column(children: [chart, const SizedBox(height: 16), legend]);
              }
              return Row(
                children: [
                  chart,
                  const SizedBox(width: 24),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ),
        Section(
          title: 'Paid vs. share',
          child: Column(
            children: [
              for (final s in byMember)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      MemberAvatar(g.member(s.memberId), radius: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.member(s.memberId).name),
                            const SizedBox(height: 4),
                            _Bar(fraction: s.paid / maxMember, color: theme.colorScheme.primary),
                            const SizedBox(height: 3),
                            _Bar(fraction: s.consumed / maxMember, color: theme.colorScheme.tertiary),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('paid ${c.format(s.paid)}', style: theme.textTheme.bodySmall),
                            Text('share ${c.format(s.consumed)}', style: muted),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (byMonth.length > 1)
          Section(
            title: 'By month',
            child: Column(
              children: [
                for (final (month, v) in byMonth)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(DateFormat('MMMM y').format(month)),
                    trailing: Text(c.format(v)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: fraction.clamp(0.0, 1.0),
        minHeight: 6,
        color: color,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
