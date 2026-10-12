import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppPage {
  overview,
  retention,
  progression,
  funnels,
  analytic,
  events,
  parameters,
  dataHealth,
  settings,
}

final selectedPageProvider = StateProvider<AppPage>((ref) => AppPage.overview);
final parameterEventProvider = StateProvider<String?>((ref) => null);
final parameterKeyProvider = StateProvider<String>((ref) => '');
final analyticTabIndexProvider = StateProvider<int>((ref) => 0);
