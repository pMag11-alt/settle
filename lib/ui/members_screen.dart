import 'package:flutter/material.dart';

import '../domain/settle.dart';
import 'scope.dart';
import 'widgets.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _name = TextEditingController();

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await AppScope.read(context).addMember(widget.groupId, name);
    _name.clear();
  }

  Future<void> _rename(String memberId, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: controller, autofocus: true, onSubmitted: (v) => Navigator.pop(c, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty && mounted) {
      await AppScope.read(context).renameMember(widget.groupId, memberId, name.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context).group(widget.groupId)!;
    final b = balances(g);
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: ListView(
        children: [
          for (final m in g.members)
            ListTile(
              leading: MemberAvatar(m),
              title: Text(m.name),
              subtitle: BalanceText(b[m.id] ?? 0, g.currency, style: Theme.of(context).textTheme.bodySmall),
              trailing: IconButton(
                tooltip: 'Rename',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _rename(m.id, m.name),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Add someone',
                suffixIcon: IconButton(icon: const Icon(Icons.person_add_alt), onPressed: _add),
              ),
              onSubmitted: (_) => _add(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'People stay in the group once added, so past expenses keep adding up. '
              'Someone who joins later simply isn’t part of earlier splits.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
