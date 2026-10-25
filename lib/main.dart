import 'package:flutter/material.dart';

import 'data/store.dart';
import 'state/app_state.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(await PrefsStore.open());
  await state.load();

  // On the web, ?demo=balances (or expenses, insights, home) loads the
  // sample trip into an empty browser and opens it on that tab, so a link
  // can show the app with data in it.
  final demo = Uri.base.queryParameters['demo'];
  if (demo != null && state.groups.isEmpty) await state.addSampleGroup();
  final tab = const {'expenses': 0, 'balances': 1, 'insights': 2}[demo];

  runApp(SettleApp(state: state, openFirstGroupOnTab: tab));
}
