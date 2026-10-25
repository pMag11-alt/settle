import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settle/data/store.dart';
import 'package:settle/state/app_state.dart';
import 'package:settle/ui/app.dart';

/// Visits every screen on a small phone (360 x 740 dp). Flutter reports any
/// overflowing layout as a test failure, so this catches clipped UI.
void main() {
  for (final brightness in Brightness.values) {
    testWidgets('every screen fits a 360dp-wide phone ($brightness)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final state = AppState(MemoryStore());
      await state.load();
      await tester.pumpWidget(SettleApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try a sample trip'));
      await tester.pumpAndSettle();

      for (final tab in ['Balances', 'Insights', 'Expenses']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Cab to the airport'));
      await tester.pumpAndSettle();
      for (final mode in ['Exact amounts', 'Percentages', 'Shares', 'Equally']) {
        await tester.ensureVisible(find.text(mode));
        await tester.tap(find.text(mode));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      for (final item in ['People', 'Activity']) {
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text(item));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('New group'));
      await tester.pumpAndSettle();
      expect(find.text('Create group'), findsOneWidget);
    });
  }
}
