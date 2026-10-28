import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';

UserEntity _user({
  String? email = 'ana@example.com',
  Object? verified,
}) =>
    UserEntity(
      id: 'u1',
      email: email,
      metadata: {if (verified != null) 'email_verified': verified},
    );

void main() {
  group('UserEntity.needsEmailVerification', () {
    test('only an explicit false asks to verify', () {
      expect(_user(verified: false).needsEmailVerification, isTrue);
      expect(_user(verified: true).needsEmailVerification, isFalse);
      // Older server or unknown value: never nag.
      expect(_user().needsEmailVerification, isFalse);
      expect(_user(verified: 'false').needsEmailVerification, isFalse);
    });

    test('a profile without email never asks', () {
      expect(
        _user(email: null, verified: false).needsEmailVerification,
        isFalse,
      );
    });
  });
}
