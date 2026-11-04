import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Runs once per test file. Loads date symbols for every locale and starts
/// each file in the app's fallback language (es), like a fresh install, so
/// Spanish date expectations hold without per-test setup.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting();
  Intl.defaultLocale = 'es';
  await testMain();
}
