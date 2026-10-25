import 'money.dart';

class Member {
  const Member({required this.id, required this.name, required this.color});

  final String id;
  final String name;

  /// Index into the avatar palette.
  final int color;

  Member copyWith({String? name}) => Member(id: id, name: name ?? this.name, color: color);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'color': color};

  factory Member.fromJson(Map<String, Object?> j) =>
      Member(id: j['id'] as String, name: j['name'] as String, color: j['color'] as int);
}

enum Category {
  food('Food & drink'),
  groceries('Groceries'),
  travel('Travel'),
  stay('Stay'),
  rent('Rent & bills'),
  fun('Entertainment'),
  shopping('Shopping'),
  other('Other');

  const Category(this.label);

  final String label;
}

enum SplitMode {
  equal('Equally'),
  exact('Exact amounts'),
  percent('Percentages'),
  shares('Shares');

  const SplitMode(this.label);

  final String label;
}

class SplitError implements Exception {
  SplitError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// How an expense is divided. [values] depends on the mode:
///  - equal: participants map to 1
///  - exact: minor units each participant owes (must sum to the total)
///  - percent: basis points, 100.00% = 10000 (must sum to 10000)
///  - shares: positive integer weights
class Split {
  const Split(this.mode, this.values);

  Split.equal(Iterable<String> memberIds) : this(SplitMode.equal, {for (final id in memberIds) id: 1});

  final SplitMode mode;
  final Map<String, int> values;

  Iterable<String> get participants => values.entries.where((e) => e.value > 0).map((e) => e.key);

  /// What each participant owes for an expense of [total], in member order
  /// of [values]. Throws [SplitError] if the split does not add up.
  Map<String, int> shares(int total) {
    final ids = participants.toList();
    if (ids.isEmpty) throw SplitError('Choose at least one person to split with');
    switch (mode) {
      case SplitMode.exact:
        final sum = ids.fold<int>(0, (a, id) => a + values[id]!);
        if (sum != total) throw SplitError('Amounts add up to $sum, not $total');
        return {for (final id in ids) id: values[id]!};
      case SplitMode.percent:
        final sum = ids.fold<int>(0, (a, id) => a + values[id]!);
        if (sum != 10000) throw SplitError('Percentages add up to ${sum / 100}%, not 100%');
        final parts = allocate(total, [for (final id in ids) values[id]!]);
        return {for (var i = 0; i < ids.length; i++) ids[i]: parts[i]};
      case SplitMode.equal:
      case SplitMode.shares:
        final weights = [for (final id in ids) mode == SplitMode.equal ? 1 : values[id]!];
        final parts = allocate(total, weights);
        return {for (var i = 0; i < ids.length; i++) ids[i]: parts[i]};
    }
  }

  Map<String, Object?> toJson() => {'mode': mode.name, 'values': values};

  factory Split.fromJson(Map<String, Object?> j) => Split(
    SplitMode.values.byName(j['mode'] as String),
    (j['values'] as Map).map((k, v) => MapEntry(k as String, v as int)),
  );
}

class Expense {
  const Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.split,
    required this.category,
    required this.date,
    this.notes = '',
  });

  final String id;
  final String description;
  final int amount;
  final String paidBy;
  final Split split;
  final Category category;
  final DateTime date;
  final String notes;

  Map<String, int> get shares => split.shares(amount);

  Map<String, Object?> toJson() => {
    'id': id,
    'description': description,
    'amount': amount,
    'paidBy': paidBy,
    'split': split.toJson(),
    'category': category.name,
    'date': date.toIso8601String(),
    if (notes.isNotEmpty) 'notes': notes,
  };

  factory Expense.fromJson(Map<String, Object?> j) => Expense(
    id: j['id'] as String,
    description: j['description'] as String,
    amount: j['amount'] as int,
    paidBy: j['paidBy'] as String,
    split: Split.fromJson((j['split'] as Map).cast<String, Object?>()),
    category: Category.values.byName(j['category'] as String),
    date: DateTime.parse(j['date'] as String),
    notes: (j['notes'] as String?) ?? '',
  );
}

/// Money handed from one member to another to settle a debt.
class Payment {
  const Payment({required this.id, required this.from, required this.to, required this.amount, required this.date});

  final String id;
  final String from;
  final String to;
  final int amount;
  final DateTime date;

  Map<String, Object?> toJson() => {'id': id, 'from': from, 'to': to, 'amount': amount, 'date': date.toIso8601String()};

  factory Payment.fromJson(Map<String, Object?> j) => Payment(
    id: j['id'] as String,
    from: j['from'] as String,
    to: j['to'] as String,
    amount: j['amount'] as int,
    date: DateTime.parse(j['date'] as String),
  );
}

/// A group's current state, rebuilt from its event log.
class Group {
  Group({
    required this.id,
    required this.name,
    required this.emoji,
    required this.currency,
    required this.createdAt,
    List<Member>? members,
    List<Expense>? expenses,
    List<Payment>? payments,
  }) : members = members ?? [],
       expenses = expenses ?? [],
       payments = payments ?? [];

  final String id;
  String name;
  String emoji;
  final Currency currency;
  final DateTime createdAt;
  final List<Member> members;
  final List<Expense> expenses;
  final List<Payment> payments;

  Member member(String id) => members.firstWhere(
    (m) => m.id == id,
    orElse: () => Member(id: id, name: '?', color: 0),
  );

  int get totalSpent => expenses.fold(0, (a, e) => a + e.amount);
}
