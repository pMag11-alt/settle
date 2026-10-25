import 'dart:math';

import 'model.dart';
import 'money.dart';

final _random = Random();

/// A short unique id: milliseconds since the epoch plus randomness, base 36.
String newId() =>
    DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
    _random.nextInt(1 << 30).toRadixString(36).padLeft(6, '0');

/// Everything that can happen to a group. A group's state is the fold of
/// its events in order, which gives undo (drop the last event and replay)
/// and an activity feed (render the log) for free.
sealed class GroupEvent {
  GroupEvent({DateTime? at}) : at = at ?? DateTime.now();

  final DateTime at;

  String get type;

  Map<String, Object?> payload();

  void apply(Group g);

  /// One line for the activity feed.
  String describe(Group g);

  Map<String, Object?> toJson() => {'type': type, 'at': at.toIso8601String(), ...payload()};

  static GroupEvent fromJson(Map<String, Object?> j) {
    final at = DateTime.parse(j['at'] as String);
    Map<String, Object?> obj(String key) => (j[key] as Map).cast<String, Object?>();
    return switch (j['type']) {
      'created' => GroupCreated(
        groupId: j['groupId'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String,
        currency: j['currency'] as String,
        at: at,
      ),
      'memberAdded' => MemberAdded(Member.fromJson(obj('member')), at: at),
      'memberRenamed' => MemberRenamed(j['memberId'] as String, j['name'] as String, at: at),
      'groupRenamed' => GroupRenamed(j['name'] as String, j['emoji'] as String, at: at),
      'expenseAdded' => ExpenseAdded(Expense.fromJson(obj('expense')), at: at),
      'expenseEdited' => ExpenseEdited(Expense.fromJson(obj('expense')), at: at),
      'expenseDeleted' => ExpenseDeleted(j['expenseId'] as String, at: at),
      'paymentRecorded' => PaymentRecorded(Payment.fromJson(obj('payment')), at: at),
      'paymentDeleted' => PaymentDeleted(j['paymentId'] as String, at: at),
      final t => throw FormatException('unknown event type $t'),
    };
  }
}

class GroupCreated extends GroupEvent {
  GroupCreated({required this.groupId, required this.name, required this.emoji, required this.currency, super.at});

  final String groupId;
  final String name;
  final String emoji;
  final String currency;

  @override
  String get type => 'created';

  @override
  Map<String, Object?> payload() => {'groupId': groupId, 'name': name, 'emoji': emoji, 'currency': currency};

  /// The first event is the only one that builds a group from nothing.
  Group create() => Group(id: groupId, name: name, emoji: emoji, currency: currencyFor(currency), createdAt: at);

  @override
  void apply(Group g) {}

  @override
  String describe(Group g) => 'Created the group “$name”';
}

class MemberAdded extends GroupEvent {
  MemberAdded(this.member, {super.at});

  final Member member;

  @override
  String get type => 'memberAdded';

  @override
  Map<String, Object?> payload() => {'member': member.toJson()};

  @override
  void apply(Group g) => g.members.add(member);

  @override
  String describe(Group g) => 'Added ${member.name}';
}

class MemberRenamed extends GroupEvent {
  MemberRenamed(this.memberId, this.name, {super.at});

  final String memberId;
  final String name;

  @override
  String get type => 'memberRenamed';

  @override
  Map<String, Object?> payload() => {'memberId': memberId, 'name': name};

  @override
  void apply(Group g) {
    final i = g.members.indexWhere((m) => m.id == memberId);
    if (i >= 0) g.members[i] = g.members[i].copyWith(name: name);
  }

  @override
  String describe(Group g) => 'Renamed a member to $name';
}

class GroupRenamed extends GroupEvent {
  GroupRenamed(this.name, this.emoji, {super.at});

  final String name;
  final String emoji;

  @override
  String get type => 'groupRenamed';

  @override
  Map<String, Object?> payload() => {'name': name, 'emoji': emoji};

  @override
  void apply(Group g) {
    g.name = name;
    g.emoji = emoji;
  }

  @override
  String describe(Group g) => 'Renamed the group to “$name”';
}

class ExpenseAdded extends GroupEvent {
  ExpenseAdded(this.expense, {super.at});

  final Expense expense;

  @override
  String get type => 'expenseAdded';

  @override
  Map<String, Object?> payload() => {'expense': expense.toJson()};

  @override
  void apply(Group g) => g.expenses.add(expense);

  @override
  String describe(Group g) =>
      'Added “${expense.description}”, ${g.currency.format(expense.amount)} paid by ${g.member(expense.paidBy).name}';
}

class ExpenseEdited extends GroupEvent {
  ExpenseEdited(this.expense, {super.at});

  final Expense expense;

  @override
  String get type => 'expenseEdited';

  @override
  Map<String, Object?> payload() => {'expense': expense.toJson()};

  @override
  void apply(Group g) {
    final i = g.expenses.indexWhere((e) => e.id == expense.id);
    if (i >= 0) g.expenses[i] = expense;
  }

  @override
  String describe(Group g) => 'Edited “${expense.description}” (now ${g.currency.format(expense.amount)})';
}

class ExpenseDeleted extends GroupEvent {
  ExpenseDeleted(this.expenseId, {super.at});

  final String expenseId;

  @override
  String get type => 'expenseDeleted';

  @override
  Map<String, Object?> payload() => {'expenseId': expenseId};

  // Remembered at apply time so the feed can still name a deleted expense.
  String _description = 'an expense';

  @override
  void apply(Group g) {
    final i = g.expenses.indexWhere((e) => e.id == expenseId);
    if (i >= 0) {
      _description = '“${g.expenses[i].description}”';
      g.expenses.removeAt(i);
    }
  }

  @override
  String describe(Group g) => 'Deleted $_description';
}

class PaymentRecorded extends GroupEvent {
  PaymentRecorded(this.payment, {super.at});

  final Payment payment;

  @override
  String get type => 'paymentRecorded';

  @override
  Map<String, Object?> payload() => {'payment': payment.toJson()};

  @override
  void apply(Group g) => g.payments.add(payment);

  @override
  String describe(Group g) =>
      '${g.member(payment.from).name} paid ${g.member(payment.to).name} ${g.currency.format(payment.amount)}';
}

class PaymentDeleted extends GroupEvent {
  PaymentDeleted(this.paymentId, {super.at});

  final String paymentId;

  @override
  String get type => 'paymentDeleted';

  @override
  Map<String, Object?> payload() => {'paymentId': paymentId};

  @override
  void apply(Group g) => g.payments.removeWhere((p) => p.id == paymentId);

  @override
  String describe(Group g) => 'Removed a payment';
}

/// A group and the log it was built from.
class GroupLog {
  GroupLog(List<GroupEvent> events) : events = List.of(events), state = replay(events);

  final List<GroupEvent> events;
  Group state;

  static Group replay(List<GroupEvent> events) {
    if (events.isEmpty || events.first is! GroupCreated) {
      throw const FormatException('a group log must start with GroupCreated');
    }
    final g = (events.first as GroupCreated).create();
    for (final e in events.skip(1)) {
      e.apply(g);
    }
    return g;
  }

  void append(GroupEvent e) {
    e.apply(state);
    events.add(e);
  }

  /// Removes the most recent event (never the creation) and rebuilds.
  GroupEvent? undo() {
    if (events.length <= 1) return null;
    final last = events.removeLast();
    state = replay(events);
    return last;
  }

  List<Map<String, Object?>> toJson() => [for (final e in events) e.toJson()];

  factory GroupLog.fromJson(List<Object?> json) =>
      GroupLog([for (final e in json) GroupEvent.fromJson((e as Map).cast<String, Object?>())]);
}
