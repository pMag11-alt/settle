import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'home_screen.dart';
import 'scope.dart';

class SettleApp extends StatelessWidget {
  const SettleApp({super.key, required this.state, this.openFirstGroupOnTab});

  final AppState state;

  /// Opens the most recent group on this tab at startup (for demo links).
  final int? openFirstGroupOnTab;

  static ThemeData theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E), brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Settle',
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        home: HomeScreen(openFirstGroupOnTab: openFirstGroupOnTab),
      ),
    );
  }
}
