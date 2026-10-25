import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settle/data/store.dart';
import 'package:settle/domain/settle.dart';
import 'package:settle/state/app_state.dart';
import 'package:settle/ui/app.dart';

Future<AppState> pumpApp(WidgetTester tester, {MemoryStore? store}) async {
  // A tall phone-sized screen so lists don't need scrolling.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final state = AppState(store ?? MemoryStore());
  await state.load();
  await tester.pumpWidget(SettleApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> openSample(WidgetTester tester) async {
  await tester.tap(find.text('Try a sample trip'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first run offers a sample trip that opens with its expenses', (tester) async {
    await pumpApp(tester);
    expect(find.text('Split costs with friends'), findsOneWidget);
    await openSample(tester);
    expect(find.text('🏖️  Goa trip'), findsOneWidget);
    expect(find.text('₹71,370.00'), findsOneWidget);
    expect(find.text('Dinner at Thalassa'), findsOneWidget);
  });

  testWidgets('adding an expense updates the list and the balances', (tester) async {
    final state = await pumpApp(tester);
    await openSample(tester);
    final g = state.groups.single;
    final before = balances(g)['asha']!;

    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount')), '400');
    await tester.enterText(find.byKey(const Key('description')), 'Chai and pakoras');
    await tester.pump();
    expect(find.text('₹100.00'), findsNWidgets(4)); // live preview of an equal split
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(find.text('Chai and pakoras'), findsOneWidget);
    // Asha paid 400 and owes 100 of it.
    expect(balances(state.groups.single)['asha'], before + 30000);
  });

  testWidgets('an exact split that does not add up is explained and not saved', (tester) async {
    final state = await pumpApp(tester);
    await openSample(tester);
    final count = state.groups.single.expenses.length;

    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount')), '1000');
    await tester.enterText(find.byKey(const Key('description')), 'Kayaking');
    await tester.tap(find.text('Exact amounts'));
    await tester.pumpAndSettle();
    // Switching modes pre-fills an even split...
    expect(find.text('250.00'), findsNWidgets(4));
    // ...which we break on purpose.
    await tester.enterText(find.text('250.00').first, '50');
    await tester.pump();
    expect(find.text('₹200.00 left to assign'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsWidgets); // still on the editor
    expect(state.groups.single.expenses.length, count);
  });

  testWidgets('recording a suggested payment shrinks the plan', (tester) async {
    final state = await pumpApp(tester);
    await openSample(tester);
    await tester.tap(find.text('Balances'));
    await tester.pumpAndSettle();
    final before = settleOptimal(balances(state.groups.single)).length;
    expect(find.text('Record'), findsNWidgets(before));

    await tester.tap(find.text('Record').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();

    expect(settleOptimal(balances(state.groups.single)).length, before - 1);
    expect(find.text('Record'), findsNWidgets(before - 1));
  });

  testWidgets('undo brings back a deleted expense', (tester) async {
    final state = await pumpApp(tester);
    await openSample(tester);
    await tester.drag(find.text('Souvenirs'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Souvenirs'), findsNothing);
    expect(state.groups.single.expenses.any((e) => e.description == 'Souvenirs'), isFalse);

    await tester.tap(find.byTooltip('Undo the last change'));
    await tester.pumpAndSettle();
    expect(find.text('Souvenirs'), findsOneWidget);
  });

  testWidgets('groups survive a restart', (tester) async {
    final store = MemoryStore();
    final first = await pumpApp(tester, store: store);
    await openSample(tester);
    await first.deleteExpense(first.groups.single.id, 'sample-0');

    final again = AppState(store);
    await again.load();
    expect(again.groups.single.name, 'Goa trip');
    expect(again.groups.single.expenses.length, 9);
  });

  testWidgets('creating a group from scratch', (tester) async {
    final state = await pumpApp(tester);
    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Flat 4B');
    for (final name in ['Meera', 'Arjun', 'Zoya']) {
      await tester.enterText(find.widgetWithText(TextField, 'Add people'), name);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();
    expect(state.groups.single.members.map((m) => m.name), ['Meera', 'Arjun', 'Zoya']);
    expect(find.text('No expenses yet'), findsOneWidget);
  });
}
