import 'package:flutter/foundation.dart';

import '../data/store.dart';
import '../domain/events.dart';
import '../domain/model.dart';
import 'sample.dart';

/// All groups, their logs, and the operations the UI performs. Every change
/// is appended to a group's event log and saved before listeners hear of it.
class AppState extends ChangeNotifier {
  AppState(this.store);

  final Store store;
  final Map<String, GroupLog> _logs = {};
  final List<String> _order = [];
  bool loaded = false;

  Future<void> load() async {
    _order
      ..clear()
      ..addAll(await store.loadIndex());
    for (final id in List.of(_order)) {
      final json = await store.loadLog(id);
      if (json == null) {
        _order.remove(id);
        continue;
      }
      try {
        _logs[id] = GroupLog.fromJson(json);
      } on Object {
        // A corrupt log should not take every other group down with it.
        _order.remove(id);
      }
    }
    loaded = true;
    notifyListeners();
  }

  /// Most recently created first.
  List<Group> get groups => [for (final id in _order.reversed) _logs[id]!.state];

  Group? group(String id) => _logs[id]?.state;

  GroupLog log(String id) => _logs[id]!;

  Future<void> _commit(String groupId, GroupEvent e) async {
    final log = _logs[groupId]!;
    log.append(e);
    await store.saveLog(groupId, log.toJson());
    notifyListeners();
  }

  Future<String> createGroup({
    required String name,
    required String emoji,
    required String currency,
    required List<String> memberNames,
  }) async {
    final id = newId();
    final log = GroupLog([GroupCreated(groupId: id, name: name, emoji: emoji, currency: currency)]);
    for (var i = 0; i < memberNames.length; i++) {
      log.append(MemberAdded(Member(id: newId(), name: memberNames[i], color: i)));
    }
    _logs[id] = log;
    _order.add(id);
    await store.saveLog(id, log.toJson());
    await store.saveIndex(_order);
    notifyListeners();
    return id;
  }

  Future<String> addSampleGroup() async {
    final log = sampleTrip();
    final id = log.state.id;
    _logs[id] = log;
    _order.add(id);
    await store.saveLog(id, log.toJson());
    await store.saveIndex(_order);
    notifyListeners();
    return id;
  }

  Future<void> deleteGroup(String id) async {
    _logs.remove(id);
    _order.remove(id);
    await store.deleteLog(id);
    await store.saveIndex(_order);
    notifyListeners();
  }

  Future<void> renameGroup(String id, String name, String emoji) => _commit(id, GroupRenamed(name, emoji));

  Future<void> addMember(String groupId, String name) {
    final g = _logs[groupId]!.state;
    return _commit(groupId, MemberAdded(Member(id: newId(), name: name, color: g.members.length)));
  }

  Future<void> renameMember(String groupId, String memberId, String name) =>
      _commit(groupId, MemberRenamed(memberId, name));

  Future<void> saveExpense(String groupId, Expense e) {
    final exists = _logs[groupId]!.state.expenses.any((x) => x.id == e.id);
    return _commit(groupId, exists ? ExpenseEdited(e) : ExpenseAdded(e));
  }

  Future<void> deleteExpense(String groupId, String expenseId) => _commit(groupId, ExpenseDeleted(expenseId));

  Future<void> recordPayment(String groupId, String from, String to, int amount) =>
      _commit(groupId, PaymentRecorded(Payment(id: newId(), from: from, to: to, amount: amount, date: DateTime.now())));

  Future<void> deletePayment(String groupId, String paymentId) => _commit(groupId, PaymentDeleted(paymentId));

  /// Reverts the latest change to a group and returns it, if any.
  Future<GroupEvent?> undo(String groupId) async {
    final log = _logs[groupId]!;
    final undone = log.undo();
    if (undone != null) {
      await store.saveLog(groupId, log.toJson());
      notifyListeners();
    }
    return undone;
  }
}
