import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/providers.dart';
import 'src/screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(baseUrlPrefKey) ?? defaultBaseUrl;
  runApp(ProviderScope(
    overrides: [baseUrlProvider.overrideWith(() => BaseUrlNotifier(saved))],
    child: const AnalyticApp(),
  ));
}

class AnalyticApp extends StatelessWidget {
  const AnalyticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnalyticTracker',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark, useMaterial3: true),
      home: const HomeShell(),
    );
  }
}
