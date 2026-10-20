import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = ['es', 'en', 'fr', 'pt-BR'];

Map<String, dynamic> _load(String locale) => jsonDecode(
      File('assets/translations/$locale.json').readAsStringSync(),
    ) as Map<String, dynamic>;

Object? _at(Map<String, dynamic> json, String dotted) {
  Object? node = json;
  for (final segment in dotted.split('.')) {
    if (node is! Map<String, dynamic>) return null;
    node = node[segment];
  }
  return node;
}

Set<String> _placeholders(String text) =>
    RegExp(r'\{(\w+)\}').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  /// Llave -> placeholders que el texto DEBE conservar en todos los idiomas.
  const keys = <String, Set<String>>{
    'coordinator.nav.consent_title': {},
    'coordinator.nav.consent_subtitle': {},
    'coordinator.consent_review.title': {},
    'coordinator.consent_review.refresh_tooltip': {},
    'coordinator.consent_review.empty_title': {},
    'coordinator.consent_review.empty_subtitle': {},
    'coordinator.consent_review.empty_more_subtitle': {},
    'coordinator.consent_review.progress': {'checked', 'total'},
    'coordinator.consent_review.load_more': {},
    'coordinator.consent_review.forms_one': {'count'},
    'coordinator.consent_review.forms_other': {'count'},
    'coordinator.consent_review.load_error': {},
    'coordinator.consent_review.retry': {},
    'coordinator.consent_review.failed_one': {'count'},
    'coordinator.consent_review.failed_other': {'count'},
    'coordinator.consent_review.retry_failed': {},
    'coordinator.consent_review.dropped_one': {'count'},
    'coordinator.consent_review.dropped_other': {'count'},
  };

  for (final locale in _locales) {
    test('consent review copy exists in $locale with its placeholders', () {
      final json = _load(locale);
      for (final entry in keys.entries) {
        final value = _at(json, entry.key);
        expect(value, isA<String>(), reason: '$locale ${entry.key} missing');
        expect((value as String).trim(), isNotEmpty, reason: entry.key);
        expect(_placeholders(value), entry.value,
            reason: '$locale ${entry.key}');
      }
    });
  }

  test('non-Spanish locales do not copy the Spanish text', () {
    final es = _load('es');
    for (final locale in ['en', 'fr', 'pt-BR']) {
      final other = _load(locale);
      for (final key in keys.keys) {
        expect(_at(other, key), isNot(_at(es, key)),
            reason: '$locale $key is untranslated');
      }
    }
  });
}
