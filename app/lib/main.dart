import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/providers.dart';
import 'src/shell/app_shell.dart';
import 'src/state/style.dart';
import 'src/theme/app_style.dart';

import 'src/theme/motion_policy.dart';

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
    final selectedTheme = buildTheme(ref.watch(styleProvider));
    final app = Builder(
      builder: (context) => MaterialApp(
        title: 'PVM Analytics',
        debugShowCheckedModeBanner: false,
        theme: selectedTheme,
        themeAnimationDuration: motionDuration(context, MotionKind.theme),
        home: const AppShell(),
      ),
    );
    return MediaQuery.maybeOf(context) != null
        ? app
        : MediaQuery.fromView(view: View.of(context), child: app);
  }
}
