import 'model.dart';

/// Spending per category, largest first.
List<(Category, int)> spendingByCategory(Group g) {
  final totals = <Category, int>{};
  for (final e in g.expenses) {
    totals[e.category] = (totals[e.category] ?? 0) + e.amount;
  }
  return totals.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
}

class MemberSpending {
  const MemberSpending(this.memberId, this.paid, this.consumed);

  final String memberId;

  /// What they paid for others and themselves.
  final int paid;

  /// Their share of the expenses.
  final int consumed;
}

List<MemberSpending> spendingByMember(Group g) {
  final paid = <String, int>{};
  final consumed = <String, int>{};
  for (final e in g.expenses) {
    paid[e.paidBy] = (paid[e.paidBy] ?? 0) + e.amount;
    e.shares.forEach((id, s) => consumed[id] = (consumed[id] ?? 0) + s);
  }
  return [for (final m in g.members) MemberSpending(m.id, paid[m.id] ?? 0, consumed[m.id] ?? 0)];
}

/// Totals per calendar month, oldest first.
List<(DateTime, int)> spendingByMonth(Group g) {
  final totals = <DateTime, int>{};
  for (final e in g.expenses) {
    final month = DateTime(e.date.year, e.date.month);
    totals[month] = (totals[month] ?? 0) + e.amount;
  }
  return totals.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => a.$1.compareTo(b.$1));
}

/// A CSV of every expense and payment, one row each, with a column per
/// member showing their share. Quotes fields per RFC 4180.
String exportCsv(Group g) {
  String q(String s) => s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  final c = g.currency;
  final rows = <List<String>>[
    ['Date', 'Description', 'Category', 'Amount (${c.code})', 'Paid by', for (final m in g.members) m.name],
  ];
  final expenses = [...g.expenses]..sort((a, b) => a.date.compareTo(b.date));
  for (final e in expenses) {
    final shares = e.shares;
    rows.add([
      e.date.toIso8601String().substring(0, 10),
      e.description,
      e.category.label,
      c.plain(e.amount),
      g.member(e.paidBy).name,
      for (final m in g.members) shares.containsKey(m.id) ? c.plain(shares[m.id]!) : '',
    ]);
  }
  for (final p in g.payments) {
    rows.add([
      p.date.toIso8601String().substring(0, 10),
      'Payment to ${g.member(p.to).name}',
      'Settlement',
      c.plain(p.amount),
      g.member(p.from).name,
      for (final _ in g.members) '',
    ]);
  }
  return rows.map((r) => r.map(q).join(',')).join('\n');
}
