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

  test('the instructor proposal copy exists in all four languages', () {
    const keys = [
      'cta',
      'change',
      'replace',
      'pending',
      'pending_keeps',
      'pending_keeps_none',
      'cancel',
      'rejected',
      'reason',
      'confirm_title',
      'confirm_body',
      'confirm',
      'dismiss',
      'cancel_title',
      'cancel_body',
      'cancel_body_none',
      'back',
      'unchanged',
      'error',
      'cancel_error',
      'rate_limited',
      'semantics_pending',
      'semantics_rejected',
      'current_none',
    ];
    for (final lang in ['es', 'en', 'fr', 'pt-BR']) {
      final json = jsonDecode(
        File('assets/translations/$lang.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final evidence = (json['honors'] as Map)['evidence'] as Map;
      for (final key in keys) {
        final text = evidence['instructor_proposal_$key'];
        expect(text, isA<String>(), reason: '$lang instructor_proposal_$key');
        expect((text as String).trim(), isNotEmpty);
      }
      // Placeholders survive translation.
      expect(evidence['instructor_proposal_confirm_title'], contains('{name}'));
      expect(evidence['instructor_proposal_reason'], contains('{reason}'));
    }
  });

  test('the Spanish copy says Especialidad, never Honor', () {
    final json = jsonDecode(
      File('assets/translations/es.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final evidence = (json['honors'] as Map)['evidence'] as Map;
    for (final key in [
      'status_changed',
      'submit_needs_date',
      'instructor_proposal_confirm_body',
      'instructor_proposal_cta',
    ]) {
      expect(
          (evidence[key] as String).toLowerCase().contains('honor'), isFalse);
    }
  });
}
