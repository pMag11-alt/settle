import '../domain/events.dart';
import '../domain/model.dart';

/// A realistic trip for first-time users to explore, using every split mode.
GroupLog sampleTrip({DateTime? now}) {
  final today = now ?? DateTime.now();
  final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 9));
  DateTime day(int d, [int hour = 12]) => start.add(Duration(days: d, hours: hour));

  final id = newId();
  final log = GroupLog([GroupCreated(groupId: id, name: 'Goa trip', emoji: '🏖️', currency: 'INR', at: day(0, 9))]);
  const asha = Member(id: 'asha', name: 'Asha', color: 0);
  const rahul = Member(id: 'rahul', name: 'Rahul', color: 1);
  const priya = Member(id: 'priya', name: 'Priya', color: 2);
  const kabir = Member(id: 'kabir', name: 'Kabir', color: 3);
  for (final m in [asha, rahul, priya, kabir]) {
    log.append(MemberAdded(m, at: day(0, 9)));
  }
  final everyone = ['asha', 'rahul', 'priya', 'kabir'];
  var n = 0;
  void spend(String what, int rupees, String payer, Split split, Category c, DateTime when) {
    log.append(
      ExpenseAdded(
        Expense(
          id: 'sample-${n++}',
          description: what,
          amount: rupees * 100,
          paidBy: payer,
          split: split,
          category: c,
          date: when,
        ),
        at: when,
      ),
    );
  }

  spend('Flights to Goa', 18400, 'asha', Split.equal(everyone), Category.travel, day(0, 10));
  spend('Villa, 4 nights', 24000, 'rahul', Split.equal(everyone), Category.stay, day(1, 14));
  spend(
    'Scooter rentals',
    3200,
    'kabir',
    const Split(SplitMode.exact, {'asha': 80000, 'rahul': 80000, 'kabir': 160000}),
    Category.travel,
    day(1, 16),
  );
  spend('Groceries for the villa', 2140, 'asha', Split.equal(everyone), Category.groceries, day(1, 18));
  spend('Dinner at Thalassa', 6850, 'priya', Split.equal(everyone), Category.food, day(2, 21));
  spend('Parasailing', 4500, 'rahul', Split.equal(['rahul', 'priya', 'kabir']), Category.fun, day(3, 11));
  spend('Beach shack lunch', 1980, 'kabir', Split.equal(everyone), Category.food, day(3, 14));
  spend(
    'Club entry',
    6000,
    'asha',
    const Split(SplitMode.shares, {'asha': 1, 'rahul': 1, 'kabir': 1}),
    Category.fun,
    day(3, 22),
  );
  spend(
    'Souvenirs',
    2700,
    'priya',
    const Split(SplitMode.exact, {'priya': 150000, 'asha': 120000}),
    Category.shopping,
    day(4, 17),
  );
  spend(
    'Cab to the airport',
    1600,
    'priya',
    const Split(SplitMode.percent, {'asha': 2500, 'rahul': 2500, 'priya': 2500, 'kabir': 2500}),
    Category.travel,
    day(5, 8),
  );
  log.append(
    PaymentRecorded(
      Payment(id: 'sample-pay', from: 'kabir', to: 'asha', amount: 200000, date: day(6)),
      at: day(6),
    ),
  );
  return log;
}
