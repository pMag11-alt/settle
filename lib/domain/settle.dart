import 'model.dart';

/// Net balance per member: positive means the group owes them money,
/// negative means they owe the group. Balances always sum to zero.
Map<String, int> balances(Group g) {
  final b = {for (final m in g.members) m.id: 0};
  for (final e in g.expenses) {
    b[e.paidBy] = (b[e.paidBy] ?? 0) + e.amount;
    e.shares.forEach((id, share) => b[id] = (b[id] ?? 0) - share);
  }
  for (final p in g.payments) {
    b[p.from] = (b[p.from] ?? 0) + p.amount;
    b[p.to] = (b[p.to] ?? 0) - p.amount;
  }
  return b;
}

class Transfer {
  const Transfer(this.from, this.to, this.amount);

  final String from;
  final String to;
  final int amount;

  @override
  String toString() => '$from -> $to: $amount';
}

/// The classic heuristic: repeatedly let the biggest debtor pay the biggest
/// creditor. Each step clears at least one person, so it needs at most
/// n - 1 transfers, but it can miss groups of people who could settle
/// among themselves.
List<Transfer> settleGreedy(Map<String, int> balance) {
  final creditors = [
    for (final e in balance.entries)
      if (e.value > 0) [e.key, e.value],
  ];
  final debtors = [
    for (final e in balance.entries)
      if (e.value < 0) [e.key, -e.value],
  ];
  int byAmount(List<Object> a, List<Object> b) => (b[1] as int).compareTo(a[1] as int);
  final out = <Transfer>[];
  while (creditors.isNotEmpty && debtors.isNotEmpty) {
    creditors.sort(byAmount);
    debtors.sort(byAmount);
    final c = creditors.first;
    final d = debtors.first;
    final amount = (c[1] as int) < (d[1] as int) ? c[1] as int : d[1] as int;
    out.add(Transfer(d[0] as String, c[0] as String, amount));
    c[1] = (c[1] as int) - amount;
    d[1] = (d[1] as int) - amount;
    if (c[1] == 0) creditors.removeAt(0);
    if (d[1] == 0) debtors.removeAt(0);
  }
  return out;
}

/// Above this many people with a non-zero balance the exact search (2^k
/// states) gets slow, and we fall back to [settleGreedy].
const exactLimit = 18;

/// The fewest transfers that settle everyone.
///
/// A set of people whose balances sum to zero can always settle among
/// themselves with (size - 1) transfers, and never with fewer. So the
/// minimum number of transfers is k - p, where k is the number of people
/// with a non-zero balance and p is the largest number of disjoint
/// zero-sum groups they can be split into. Finding p is NP-hard in
/// general, but a DP over subsets solves it exactly in O(2^k * k):
///
///   best[mask] = max over i in mask of best[mask without i]
///                + (1 if sum(mask) == 0 else 0)
///
/// Removing people one at a time and counting how often the remaining
/// set sums to zero counts the zero-sum blocks of a partition. Walking the
/// choices back recovers the blocks, and each is settled greedily.
List<Transfer> settleOptimal(Map<String, int> balance) {
  final ids = [
    for (final e in balance.entries)
      if (e.value != 0) e.key,
  ];
  final k = ids.length;
  if (k > exactLimit) return settleGreedy(balance);
  final values = [for (final id in ids) balance[id]!];
  final full = (1 << k) - 1;

  final sum = List<int>.filled(1 << k, 0);
  for (var mask = 1; mask <= full; mask++) {
    final low = mask & -mask;
    sum[mask] = sum[mask ^ low] + values[low.bitLength - 1];
  }
  final best = List<int>.filled(1 << k, 0);
  for (var mask = 1; mask <= full; mask++) {
    var top = -1;
    for (var rest = mask; rest != 0; rest &= rest - 1) {
      final bit = rest & -rest;
      final v = best[mask ^ bit];
      if (v > top) top = v;
    }
    best[mask] = top + (sum[mask] == 0 ? 1 : 0);
  }

  // Walk back from the full set. The people removed between two zero-sum
  // states form one block that settles on its own.
  final out = <Transfer>[];
  var block = <String, int>{};
  var mask = full;
  while (mask != 0) {
    final atZero = sum[mask] == 0 ? 1 : 0;
    var chosen = -1;
    for (var rest = mask; rest != 0; rest &= rest - 1) {
      final bit = rest & -rest;
      if (best[mask ^ bit] + atZero == best[mask]) {
        chosen = bit;
        break;
      }
    }
    final i = chosen.bitLength - 1;
    block[ids[i]] = values[i];
    mask ^= chosen;
    if (sum[mask] == 0) {
      out.addAll(settleGreedy(block));
      block = {};
    }
  }
  return out;
}

/// Who owes whom without any simplification: for every expense, each
/// participant owes the payer their share, netted per pair of people.
List<Transfer> pairwiseDebts(Group g) {
  final owed = <(String, String), int>{};
  void add(String from, String to, int amount) {
    if (from == to || amount == 0) return;
    final (a, b) = from.compareTo(to) < 0 ? (from, to) : (to, from);
    final sign = from == a ? 1 : -1;
    owed[(a, b)] = (owed[(a, b)] ?? 0) + sign * amount;
  }

  for (final e in g.expenses) {
    e.shares.forEach((id, share) => add(id, e.paidBy, share));
  }
  for (final p in g.payments) {
    add(p.to, p.from, p.amount);
  }
  return [
    for (final MapEntry(key: (a, b), :value) in owed.entries)
      if (value > 0) Transfer(a, b, value) else if (value < 0) Transfer(b, a, -value),
  ];
}
