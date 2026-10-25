import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:settle/domain/events.dart';
import 'package:settle/domain/model.dart';
import 'package:settle/domain/settle.dart';

/// Applies transfers and checks everyone ends at zero.
void expectSettles(Map<String, int> balance, List<Transfer> plan) {
  final b = Map.of(balance);
  for (final t in plan) {
    expect(t.amount, greaterThan(0));
    b[t.from] = b[t.from]! + t.amount;
    b[t.to] = b[t.to]! - t.amount;
  }
  expect(b.values.every((v) => v == 0), isTrue, reason: 'left over: $b');
}

Map<String, int> randomBalances(Random r, int n, {int maxAbs = 10000}) {
  final b = <String, int>{};
  var sum = 0;
  for (var i = 0; i < n - 1; i++) {
    final v = r.nextInt(2 * maxAbs) - maxAbs;
    b['p$i'] = v;
    sum += v;
  }
  b['p${n - 1}'] = -sum;
  return b;
}

/// Largest number of zero-sum blocks over every set partition, by brute
/// force. Only feasible for a handful of people.
int maxZeroSumBlocks(List<int> values) {
  var best = 0;
  void go(int i, List<int> blockSums) {
    if (i == values.length) {
      if (blockSums.every((s) => s == 0)) best = max(best, blockSums.length);
      return;
    }
    for (var j = 0; j < blockSums.length; j++) {
      blockSums[j] += values[i];
      go(i + 1, blockSums);
      blockSums[j] -= values[i];
    }
    blockSums.add(values[i]);
    go(i + 1, blockSums);
    blockSums.removeLast();
  }

  go(0, []);
  return best;
}

void main() {
  test('balances of a small trip', () {
    final g = Group(id: 'g', name: 'Trip', emoji: '🏖', currency: currencyForTest, createdAt: DateTime(2026));
    for (final n in ['a', 'b', 'c']) {
      g.members.add(Member(id: n, name: n, color: 0));
    }
    g.expenses.add(
      Expense(
        id: '1',
        description: 'Hotel',
        amount: 9000,
        paidBy: 'a',
        split: Split.equal(['a', 'b', 'c']),
        category: Category.stay,
        date: DateTime(2026),
      ),
    );
    g.expenses.add(
      Expense(
        id: '2',
        description: 'Taxi',
        amount: 1000,
        paidBy: 'b',
        split: Split.equal(['b', 'c']),
        category: Category.travel,
        date: DateTime(2026),
      ),
    );
    expect(balances(g), {'a': 6000, 'b': -2500, 'c': -3500});
    g.payments.add(Payment(id: 'p', from: 'c', to: 'a', amount: 3500, date: DateTime(2026)));
    expect(balances(g), {'a': 2500, 'b': -2500, 'c': 0});
    expectSettles(balances(g), settleOptimal(balances(g)));
  });

  test('the exact plan beats greedy when a subgroup can settle on its own', () {
    // a+d and b+c cancel out: 2 transfers suffice, greedy needs 3.
    final b = {'a': 50, 'b': 40, 'c': -40, 'd': -50, 'e': 0};
    final greedy = settleGreedy({'a': 50, 'b': 41, 'c': -40, 'd': -51});
    expect(greedy.length, 3);
    final optimal = settleOptimal(b);
    expect(optimal.length, 2);
    expectSettles(b, optimal);

    // Largest-first greedy pairs the -4 with the +3 and needs 4 payments.
    // Optimal notices that +3 and -3 cancel: 1 payment, then 2 for the rest.
    final readme = {'asha': 3000, 'rahul': 2000, 'priya': 2000, 'kabir': -3000, 'zoya': -4000};
    expect(settleGreedy(readme).length, 4);
    final best = settleOptimal(readme);
    expect(best.length, 3);
    expectSettles(readme, best);
    expect(best.any((t) => t.from == 'kabir' && t.to == 'asha' && t.amount == 3000), isTrue);
  });

  test('random groups: both plans settle, optimal is never worse and matches brute force', () {
    final r = Random(7);
    for (var trial = 0; trial < 400; trial++) {
      final n = r.nextInt(7) + 2;
      // Small values make zero-sum subgroups common, which is the hard case.
      final b = randomBalances(r, n, maxAbs: trial.isEven ? 6 : 1000);
      final greedy = settleGreedy(b);
      final optimal = settleOptimal(b);
      expectSettles(b, greedy);
      expectSettles(b, optimal);
      expect(optimal.length, lessThanOrEqualTo(greedy.length));
      final nonZero = b.values.where((v) => v != 0).toList();
      expect(optimal.length, nonZero.length - maxZeroSumBlocks(nonZero), reason: '$b');
    }
  });

  test('large groups fall back to greedy quickly', () {
    final b = randomBalances(Random(3), 40);
    final sw = Stopwatch()..start();
    final plan = settleOptimal(b);
    expectSettles(b, plan);
    expect(sw.elapsedMilliseconds, lessThan(1000));
  });

  test('the exact search handles its full size limit', () {
    final b = randomBalances(Random(4), exactLimit, maxAbs: 20);
    final sw = Stopwatch()..start();
    expectSettles(b, settleOptimal(b));
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });

  test('pairwise debts net out per pair', () {
    final g = Group(id: 'g', name: 'Flat', emoji: '🏠', currency: currencyForTest, createdAt: DateTime(2026));
    for (final n in ['a', 'b']) {
      g.members.add(Member(id: n, name: n, color: 0));
    }
    g.expenses.add(
      Expense(
        id: '1',
        description: 'Rent',
        amount: 1000,
        paidBy: 'a',
        split: Split.equal(['a', 'b']),
        category: Category.rent,
        date: DateTime(2026),
      ),
    );
    g.expenses.add(
      Expense(
        id: '2',
        description: 'Food',
        amount: 400,
        paidBy: 'b',
        split: Split.equal(['a', 'b']),
        category: Category.food,
        date: DateTime(2026),
      ),
    );
    final debts = pairwiseDebts(g);
    expect(debts.length, 1);
    expect((debts.single.from, debts.single.to, debts.single.amount), ('b', 'a', 300));
  });

  test('event log round-trips through JSON and supports undo', () {
    final log = GroupLog([GroupCreated(groupId: 'g', name: 'Goa', emoji: '🏖', currency: 'INR')]);
    log.append(MemberAdded(const Member(id: 'a', name: 'Asha', color: 1)));
    log.append(MemberAdded(const Member(id: 'b', name: 'Rahul', color: 2)));
    final e = Expense(
      id: 'e',
      description: 'Dinner, "the good one"',
      amount: 4200,
      paidBy: 'a',
      split: const Split(SplitMode.shares, {'a': 1, 'b': 2}),
      category: Category.food,
      date: DateTime(2026, 3, 4),
    );
    log.append(ExpenseAdded(e));
    log.append(PaymentRecorded(Payment(id: 'p', from: 'b', to: 'a', amount: 1000, date: DateTime(2026, 3, 5))));
    log.append(ExpenseDeleted('e'));

    final copy = GroupLog.fromJson(log.toJson());
    expect(copy.state.expenses, isEmpty);
    expect(copy.state.payments.single.amount, 1000);
    expect(copy.state.members.map((m) => m.name), ['Asha', 'Rahul']);

    expect(copy.undo(), isA<ExpenseDeleted>());
    expect(copy.state.expenses.single.description, 'Dinner, "the good one"');
    expect(copy.state.expenses.single.shares, {'a': 1400, 'b': 2800});
    // Asha paid 4200 and owes 1400 of it; Rahul has paid back 1000.
    expect(balances(copy.state), {'a': 1800, 'b': -1800});
  });
}

final currencyForTest = GroupCreated(groupId: 'x', name: '', emoji: '', currency: 'INR').create().currency;
