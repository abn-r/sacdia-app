import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/analytics/pairing_redaction.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('redactPairingLinks', () {
    test('keeps the link but drops the token', () {
      const url = 'sacdia://pair?c=SECRET_token-1';
      final out = redactPairingLinks('opened $url now');
      expect(out, 'opened sacdia://pair?$kRedacted now');
      expect(out, isNot(contains('SECRET')));
    });

    test('handles both parameter names and the three-slash form', () {
      for (final url in [
        'sacdia://pair?t=SECRET',
        'sacdia:///pair?c=SECRET&x=1',
        'SACDIA://PAIR?c=SECRET',
      ]) {
        expect(redactPairingLinks(url), isNot(contains('SECRET')), reason: url);
      }
    });

    test('leaves unrelated text alone', () {
      expect(redactPairingLinks('GET /users/me'), 'GET /users/me');
      expect(redactPairingLinks('sacdia://other?c=x'), 'sacdia://other?c=x');
    });
  });

  group('redactPairingBreadcrumb', () {
    test('scrubs the message and nested data', () {
      final crumb = Breadcrumb(
        message: 'navigation to sacdia://pair?c=SECRET',
        data: {
          'to': 'sacdia://pair?t=SECRET',
          'pairing_token': 'SECRET',
          'nested': {
            'url': 'sacdia://pair?c=SECRET',
            'list': ['sacdia://pair?c=SECRET', 'ok'],
          },
        },
      );

      final out = redactPairingBreadcrumb(crumb)!;

      expect(out.message, isNot(contains('SECRET')));
      expect(out.data.toString(), isNot(contains('SECRET')));
      expect(out.data!['pairing_token'], kRedacted);
      expect((out.data!['nested'] as Map)['list'], contains('ok'));
    });

    test('a null breadcrumb stays null', () {
      expect(redactPairingBreadcrumb(null), isNull);
    });
  });
}
