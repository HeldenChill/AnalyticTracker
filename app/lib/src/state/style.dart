import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_style.dart';

const stylePrefKey = 'appStyle';

class StyleNotifier extends Notifier<AppStyle> {
  StyleNotifier([this._initial = AppStyle.tremor]);
  final AppStyle _initial;

  @override
  AppStyle build() => _initial;

  /// Applies immediately; persists for the next launch on this device.
  Future<void> select(AppStyle style) async {
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(stylePrefKey, style.name);
  }
}

final styleProvider = NotifierProvider<StyleNotifier, AppStyle>(StyleNotifier.new);
