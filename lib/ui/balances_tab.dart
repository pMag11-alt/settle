import 'package:flutter/material.dart';

import '../domain/model.dart';
import '../domain/settle.dart';
import 'scope.dart';
import 'widgets.dart';

class BalancesTab extends StatefulWidget {
  const BalancesTab({super.key, required this.group});

  final Group group;

  @override
  State<BalancesTab> createState() => _BalancesTabState();
}

class _BalancesTabState extends State<BalancesTab> {
  bool _simplify = true;

  Future<void> _record(Transfer t) async {
    final g = widget.group;
    final c = g.currency;
    final controller = TextEditingController(text: c.plain(t.amount));
    final amount = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('${g.member(t.from).name} paid ${g.member(t.to).name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Amount', prefixText: c.symbol),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = c.parse(controller.text);
              if (v != null && v > 0) Navigator.pop(dialog, v);
            },
            child: const Text('Record payment'),
          ),
        ],
      ),
    );
    if (amount != null && mounted) {
      await AppScope.read(context).recordPayment(g.id, t.from, t.to, amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final theme = Theme.of(context);
    final b = balances(g);
    final maxAbs = b.values.fold<int>(1, (m, v) => v.abs() > m ? v.abs() : m);
    final optimal = settleOptimal(b);
    final greedy = settleGreedy(b);
    final pairwise = pairwiseDebts(g);
    final plan = _simplify ? optimal : pairwise;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: [
        Section(
          title: 'Balances',
          child: Column(
            children: [
              for (final m in g.members)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      MemberAvatar(m),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: theme.textTheme.bodyLarge),
                            const SizedBox(height: 4),
                            _BalanceBar(value: b[m.id] ?? 0, maxAbs: maxAbs),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 112,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            BalanceText(b[m.id] ?? 0, g.currency),
                            Text(
                              (b[m.id] ?? 0) > 0 ? 'gets back' : ((b[m.id] ?? 0) < 0 ? 'owes' : ''),
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Section(
          title: 'Settle up',
          child: optimal.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('Everyone is square 🎉')),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Fewest payments'), icon: Icon(Icons.auto_fix_high)),
                        ButtonSegment(
                          value: false,
                          label: Text('Who owes whom'),
                          icon: Icon(Icons.account_tree_outlined),
                        ),
                      ],
                      selected: {_simplify},
                      onSelectionChanged: (s) => setState(() => _simplify = s.first),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _simplify
                          ? _explainOptimal(optimal.length, greedy.length, pairwise.length)
                          : 'Every debt as it arose, netted per pair: ${pairwise.length} payment${pairwise.length == 1 ? '' : 's'}.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    for (final t in plan)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: MemberAvatar(g.member(t.from)),
                        title: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: g.member(t.from).name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const TextSpan(text: ' pays '),
                              TextSpan(
                                text: g.member(t.to).name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        subtitle: Text(g.currency.format(t.amount)),
                        trailing: OutlinedButton(onPressed: () => _record(t), child: const Text('Record')),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  String _explainOptimal(int optimal, int greedy, int pairwise) {
    final s = optimal == 1 ? '' : 's';
    if (optimal < greedy) {
      return '$optimal payment$s settle everyone, the proven minimum. The usual largest-first method would need $greedy.';
    }
    if (optimal < pairwise) {
      return '$optimal payment$s settle everyone, the proven minimum (instead of $pairwise if every debt were paid back directly).';
    }
    return '$optimal payment$s settle everyone, the proven minimum.';
  }
}

/// A bar growing right for money owed to someone, left for money they owe.
class _BalanceBar extends StatelessWidget {
  const _BalanceBar({required this.value, required this.maxAbs});

  final int value;
  final int maxAbs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = (value.abs() / maxAbs).clamp(0.0, 1.0);
    final color = value >= 0 ? positiveColor(context) : scheme.error;
    return SizedBox(
      height: 8,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: value < 0 ? fraction : 0,
                child: Container(
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ),
          Container(width: 2, color: scheme.outlineVariant),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value > 0 ? fraction : 0,
                child: Container(
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
