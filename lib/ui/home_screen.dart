import 'package:flutter/material.dart';

import '../domain/model.dart';
import '../domain/settle.dart';
import 'group_screen.dart';
import 'new_group_sheet.dart';
import 'scope.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.openFirstGroupOnTab});

  final int? openFirstGroupOnTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final tab = widget.openFirstGroupOnTab;
    if (tab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final groups = AppScope.read(context).groups;
        if (groups.isNotEmpty && mounted) _open(context, groups.first.id, tab: tab);
      });
    }
  }

  Future<void> _open(BuildContext context, String id, {int tab = 0}) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => GroupScreen(groupId: id, initialTab: tab),
    ),
  );

  Future<void> _create(BuildContext context) async {
    final id = await showNewGroupSheet(context);
    if (id != null && context.mounted) await _open(context, id);
  }

  Future<void> _sample(BuildContext context) async {
    final id = await AppScope.read(context).addSampleGroup();
    if (context.mounted) await _open(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final groups = state.groups;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settle'),
        actions: [
          if (groups.isNotEmpty)
            IconButton(
              tooltip: 'Add the sample trip',
              icon: const Icon(Icons.auto_awesome_outlined),
              onPressed: () => _sample(context),
            ),
        ],
      ),
      body: groups.isEmpty
          ? EmptyState(
              icon: Icons.groups_2_outlined,
              title: 'Split costs with friends',
              message:
                  'Make a group for a trip, a flat or a dinner. Add what everyone paid, '
                  'and Settle works out the fewest payments that make everyone square.',
              actions: [
                FilledButton.icon(
                  onPressed: () => _create(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New group'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _sample(context),
                  icon: const Icon(Icons.beach_access_outlined),
                  label: const Text('Try a sample trip'),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              children: [for (final g in groups) _GroupCard(group: g, onTap: () => _open(context, g.id))],
            ),
      floatingActionButton: groups.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _create(context),
              icon: const Icon(Icons.add),
              label: const Text('New group'),
            ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onTap});

  final Group group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = settleOptimal(balances(group)).length;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(group.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${group.members.length} people · ${group.currency.format(group.totalSpent)} spent',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(pending == 0 ? Icons.check_circle : Icons.swap_horiz, size: 18),
                label: Text(pending == 0 ? 'Settled' : '$pending to settle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
