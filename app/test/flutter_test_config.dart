import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Local settings use platform storage in production; tests must not call the
  // absent native storage plugin. Transaction tests inject their own repository.
  SharedPreferences.setMockInitialValues({});
  await testMain();
}
