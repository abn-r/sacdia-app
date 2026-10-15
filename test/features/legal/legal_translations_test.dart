import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _locales = ['es', 'en', 'fr', 'pt-BR'];

Future<Map<String, dynamic>> _load(String locale) async {
  final raw = await rootBundle.loadString('assets/translations/$locale.json');
  return jsonDecode(raw) as Map<String, dynamic>;
}

Map<String, dynamic> _namespace(Map<String, dynamic> json, List<String> path) {
  Object? node = json;
  for (final segment in path) {
    node = (node as Map<String, dynamic>)[segment];
  }
  return node as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const namespaces = <String, List<String>>{
    'auth.legal': ['auth', 'legal'],
    'legal_gate': ['legal_gate'],
  };

  const expectedKeys = <String, Set<String>>{
    'auth.legal': {
      'consent_prefix',
      'terms_link',
      'and',
      'privacy_link',
      'login_notice_prefix',
      'load_error',
      'retry',
      'open_failed',
      'consent_semantics',
    },
    'legal_gate': {
      'title',
      'body',
      'document_terms',
      'document_privacy',
      'version_label',
      'read_document',
      'accept_button',
      'sign_out',
      'load_error',
      'retry',
      'accept_error',
      'version_changed',
    },
  };

  group('Legal translations', () {
    for (final entry in namespaces.entries) {
      for (final locale in _locales) {
        test('${entry.key} defines every key for $locale', () async {
          final ns = _namespace(await _load(locale), entry.value);

          expect(ns.keys.toSet(), expectedKeys[entry.key]);
          for (final key in expectedKeys[entry.key]!) {
            expect(ns[key], isA<String>(), reason: '${entry.key}.$key');
            expect((ns[key] as String).isNotEmpty, isTrue,
                reason: '${entry.key}.$key is empty');
          }
        });
      }

      test('${entry.key} has the same keys in all locales', () async {
        final reference =
            _namespace(await _load('es'), entry.value).keys.toSet();
        for (final locale in _locales.skip(1)) {
          final keys =
              _namespace(await _load(locale), entry.value).keys.toSet();
          expect(keys, reference, reason: '${entry.key} differs in $locale');
        }
      });
    }

    test('legal_gate.version_label keeps the {version} argument', () async {
      for (final locale in _locales) {
        final gate = _namespace(await _load(locale), ['legal_gate']);
        expect(gate['version_label'], contains('{version}'), reason: locale);
      }
    });

    test('consent copy joins into a sentence with both links', () async {
      for (final locale in _locales) {
        final legal = _namespace(await _load(locale), ['auth', 'legal']);
        final sentence = '${legal['consent_prefix']}${legal['terms_link']}'
            '${legal['and']}${legal['privacy_link']}';
        expect(sentence, contains(legal['terms_link'] as String));
        expect(sentence, contains(legal['privacy_link'] as String));
        expect(sentence, isNot(contains('  ')), reason: locale);
      }
    });
  });
}
