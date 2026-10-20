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

/// Placeholders `{name}` de un texto.
Set<String> _placeholders(String text) =>
    RegExp(r'\{(\w+)\}').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  /// Llave -> placeholders que el texto DEBE conservar en todos los idiomas.
  const keys = <String, Set<String>>{
    // A01: alta de un menor por el director.
    'members.create_minor.entry': {},
    'members.create_minor.title': {},
    'members.create_minor.intro': {},
    'members.create_minor.name': {},
    'members.create_minor.paternal': {},
    'members.create_minor.maternal': {},
    'members.create_minor.birthday': {},
    'members.create_minor.birthday_hint': {},
    'members.create_minor.birthday_required': {},
    'members.create_minor.gender_label': {},
    'members.create_minor.gender_male': {},
    'members.create_minor.gender_female': {},
    'members.create_minor.required': {},
    'members.create_minor.sworn': {},
    'members.create_minor.legal_prefix': {},
    'members.create_minor.legal_unavailable': {},
    'members.create_minor.submit': {},
    'members.create_minor.created_toast': {'name'},
    'members.create_minor.errors.age_out_of_range': {},
    'members.create_minor.errors.no_active_year': {},
  };

  for (final locale in _locales) {
    group('create-minor translations ($locale)', () {
      final json = _load(locale);

      test('every key exists, is non-empty and keeps its placeholders', () {
        for (final entry in keys.entries) {
          final value = _at(json, entry.key);
          expect(value, isA<String>(), reason: '${entry.key} missing');
          expect((value as String).trim(), isNotEmpty, reason: entry.key);
          expect(_placeholders(value), entry.value, reason: entry.key);
        }
      });
    });
  }

  test('non-Spanish locales do not copy the Spanish text', () {
    final es = _load('es');
    for (final locale in ['en', 'fr', 'pt-BR']) {
      final other = _load(locale);
      for (final key in [
        'members.create_minor.intro',
        'members.create_minor.sworn',
      ]) {
        expect(_at(other, key), isNot(_at(es, key)),
            reason: '$locale $key is untranslated');
      }
    }
  });
}
