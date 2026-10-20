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

void main() {
  const keys = [
    'members.view.verify_empty_title',
    'members.view.verify_empty_subtitle',
    'members.view.verify_only_hint',
    'members.view.verify_scope_title',
    'members.view.verify_scope_subtitle',
    'members.consent.verify_only_upload_note',
  ];

  for (final locale in _locales) {
    test('verify-only members copy exists in $locale', () {
      final json = _load(locale);
      for (final key in keys) {
        final value = _at(json, key);
        expect(value, isA<String>(), reason: '$locale $key missing');
        expect((value as String).trim(), isNotEmpty, reason: '$locale $key');
      }
    });
  }

  test('non-Spanish locales do not copy the Spanish text', () {
    final es = _load('es');
    for (final locale in ['en', 'fr', 'pt-BR']) {
      final other = _load(locale);
      for (final key in keys) {
        expect(_at(other, key), isNot(_at(es, key)),
            reason: '$locale $key is untranslated');
      }
    }
  });
}
