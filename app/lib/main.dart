import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/providers.dart';
import 'src/shell/app_shell.dart';
import 'src/state/style.dart';
import 'src/theme/app_style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString(baseUrlPrefKey) ?? defaultBaseUrl;
  final savedStyle = parseStyle(prefs.getString(stylePrefKey));
  runApp(ProviderScope(
    overrides: [
      baseUrlProvider.overrideWith(() => BaseUrlNotifier(savedUrl)),
      styleProvider.overrideWith(() => StyleNotifier(savedStyle)),
    ],
    child: const AnalyticApp(),
  ));
}

class AnalyticApp extends ConsumerWidget {
  const AnalyticApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'PVM Analytics',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(ref.watch(styleProvider)),
      home: const AppShell(),
    );
  }
}
