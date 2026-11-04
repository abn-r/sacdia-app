/// Loads the real Spanish translations into easy_localization's singleton so a
/// widget test can assert user-visible copy, `plural()` included.
///
/// Without this `tr()` returns the raw key (which most widget tests rely on)
/// and `plural()` throws because no locale was ever loaded. Call it from
/// `setUpAll`; the singleton is per test isolate (per file), so it never leaks
/// into other test files.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';

void loadSpanishTranslations() {
  final raw = File('assets/translations/es.json').readAsStringSync();
  Localization.load(
    const Locale('es'),
    translations: Translations(jsonDecode(raw) as Map<String, dynamic>),
  );
}
