import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';

void main() {
  group('SocialProvider', () {
    test('wireName matches the backend route segment', () {
      expect(SocialProvider.google.wireName, 'google');
      expect(SocialProvider.apple.wireName, 'apple');
    });
  });

  group('generateNonce', () {
    test('returns a base64url string of at least 43 chars', () {
      final nonce = generateNonce();
      expect(nonce.length, greaterThanOrEqualTo(43));
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(nonce), isTrue);
    });

    test('is unique per call', () {
      expect(generateNonce(), isNot(generateNonce()));
    });
  });

  group('sha256Hex', () {
    test('matches package:crypto lowercase hex', () {
      const raw = 'raw-nonce-123';
      expect(sha256Hex(raw), sha256.convert(utf8.encode(raw)).toString());
    });
  });

  group('SocialCredential.toSignInBody', () {
    test('serialises only the fields that are set', () {
      const credential = SocialCredential(
        provider: SocialProvider.google,
        idToken: 'id-token',
        nonce: 'nonce-1',
      );
      expect(credential.toSignInBody(), {
        'idToken': 'id-token',
        'nonce': 'nonce-1',
      });
    });

    test('includes the Apple authorization code and full name', () {
      const credential = SocialCredential(
        provider: SocialProvider.apple,
        idToken: 'id-token',
        nonce: 'nonce-1',
        authorizationCode: 'code-1',
        givenName: 'Ana',
        familyName: 'Pérez',
      );
      expect(credential.toSignInBody(), {
        'idToken': 'id-token',
        'nonce': 'nonce-1',
        'authorizationCode': 'code-1',
        'fullName': {'givenName': 'Ana', 'familyName': 'Pérez'},
      });
    });

    test('omits fullName when both parts are null', () {
      const credential = SocialCredential(
        provider: SocialProvider.apple,
        idToken: 'id-token',
        nonce: 'nonce-1',
        authorizationCode: 'code-1',
      );
      expect(credential.toSignInBody().containsKey('fullName'), isFalse);
    });
  });
}
