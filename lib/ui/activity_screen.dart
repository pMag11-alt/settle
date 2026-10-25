import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/events.dart';
import 'scope.dart';

/// The group's event log, newest first. It is the same log the group's
/// state is rebuilt from.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key, required this.groupId});

  final String groupId;

  IconData _icon(GroupEvent e) => switch (e) {
    GroupCreated() => Icons.flag_outlined,
    MemberAdded() || MemberRenamed() => Icons.person_outline,
    GroupRenamed() => Icons.edit_outlined,
    ExpenseAdded() => Icons.add_circle_outline,
    ExpenseEdited() => Icons.edit_note,
    ExpenseDeleted() => Icons.remove_circle_outline,
    PaymentRecorded() => Icons.handshake_outlined,
    PaymentDeleted() => Icons.undo,
  };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = state.group(groupId)!;
    final events = state.log(groupId).events.reversed.toList();
    final when = DateFormat('d MMM, HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: ListView.separated(
        itemCount: events.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, i) => ListTile(
          leading: Icon(_icon(events[i])),
          title: Text(events[i].describe(g)),
          subtitle: Text(when.format(events[i].at)),
        ),
      ),
    );
  }
}
