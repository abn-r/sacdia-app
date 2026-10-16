import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/data/models/user_model.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';

Map<String, dynamic> _payload([Map<String, dynamic>? extra]) => {
      'user_id': 'user-1',
      'email': 'user@example.com',
      ...?extra,
    };

void main() {
  group('UserModel legal acceptance parsing', () {
    test('requires_acceptance true -> legalAcceptancePending true', () {
      final user = UserModel.fromCustomApi(_payload({
        'legal': {
          'requires_acceptance': true,
          'documents': <Map<String, dynamic>>[],
        },
      }));

      expect(user.legalAcceptancePending, isTrue);
    });

    test('requires_acceptance false -> legalAcceptancePending false', () {
      final user = UserModel.fromCustomApi(_payload({
        'legal': {'requires_acceptance': false},
      }));

      expect(user.legalAcceptancePending, isFalse);
    });

    test('missing legal block -> legalAcceptancePending false', () {
      final user = UserModel.fromCustomApi(_payload());

      expect(user.legalAcceptancePending, isFalse);
    });

    test('malformed legal block -> legalAcceptancePending false', () {
      for (final legal in <dynamic>[
        null,
        'yes',
        42,
        <dynamic>[],
        {'requires_acceptance': 'true'},
        {'requires_acceptance': 1},
        {'requires_acceptance': null},
        {},
      ]) {
        final user = UserModel.fromCustomApi(_payload({'legal': legal}));
        expect(user.legalAcceptancePending, isFalse, reason: '$legal');
      }
    });

    test('is never cached: absent from toJson and fromJson restores false', () {
      final pending = UserModel.fromCustomApi(_payload({
        'legal': {'requires_acceptance': true},
      }));

      final json = pending.toJson();
      expect(json.containsKey('legalAcceptancePending'), isFalse);
      expect(UserModel.fromJson(json).legalAcceptancePending, isFalse);
    });

    test('copyWith overrides and preserves legalAcceptancePending', () {
      final pending = UserModel.fromCustomApi(_payload({
        'legal': {'requires_acceptance': true},
      }));

      expect(pending.copyWith(name: 'Ana').legalAcceptancePending, isTrue);
      expect(
        pending.copyWith(legalAcceptancePending: false).legalAcceptancePending,
        isFalse,
      );
    });
  });

  group('UserEntity equality', () {
    test('legalAcceptancePending is part of equality', () {
      const pending = UserEntity(
        id: 'u',
        email: 'u@example.com',
        legalAcceptancePending: true,
      );
      const cleared = UserEntity(id: 'u', email: 'u@example.com');

      expect(pending, isNot(equals(cleared)));
      expect(pending.props, contains(true));
    });

    test('defaults to false', () {
      const user = UserEntity(id: 'u', email: 'u@example.com');

      expect(user.legalAcceptancePending, isFalse);
    });
  });
}
