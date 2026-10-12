import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the completion date copy exists in all four languages', () {
    const keys = [
      'completion_date_title',
      'completion_date_required',
      'submit_needs_date',
      'date_too_old',
      'date_future',
      'date_save_error',
      'status_changed',
    ];
    for (final lang in ['es', 'en', 'fr', 'pt-BR']) {
      final json = jsonDecode(
        File('assets/translations/$lang.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final evidence = (json['honors'] as Map)['evidence'] as Map;
      for (final key in keys) {
        expect(evidence[key], isA<String>(),
            reason: '$lang honors.evidence.$key');
        expect((evidence[key] as String).trim(), isNotEmpty);
      }
    }
  });

  test('the Spanish copy says Especialidad, never Honor', () {
    final json = jsonDecode(
      File('assets/translations/es.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final evidence = (json['honors'] as Map)['evidence'] as Map;
    for (final key in ['status_changed', 'submit_needs_date']) {
      expect(
          (evidence[key] as String).toLowerCase().contains('honor'), isFalse);
    }
  });
}
