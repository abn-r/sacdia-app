import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/data/models/user_model.dart';

Map<String, dynamic> _payload([Map<String, dynamic>? extra]) => {
      'user_id': 'user-1',
      'email': 'user@example.com',
      ...?extra,
    };

void main() {
  group('UserModel nullable email', () {
    test('null email stays null', () {
      final user = UserModel.fromCustomApi(_payload({'email': null}));
      expect(user.email, isNull);
    });

    test('missing, blank or non-string email is null (never an empty string)',
        () {
      for (final email in <Object?>['', '   ', 42, true]) {
        final user = UserModel.fromCustomApi(_payload({'email': email}));
        expect(user.email, isNull, reason: '$email');
      }
      final noKey = UserModel.fromCustomApi({'user_id': 'user-2'});
      expect(noKey.email, isNull);
    });

    test('a real email is kept', () {
      final user = UserModel.fromCustomApi(_payload());
      expect(user.email, 'user@example.com');
    });

    test('toJson/fromJson round-trip tolerates a null email', () {
      final user = UserModel.fromCustomApi(_payload({'email': null}));
      final restored = UserModel.fromJson(user.toJson());
      expect(restored.id, 'user-1');
      expect(restored.email, isNull);
    });

    test('copyWith keeps a null email', () {
      final user = UserModel.fromCustomApi(_payload({'email': null}));
      expect(user.copyWith(name: 'Ana').email, isNull);
    });
  });

  group('UserModel acting_for / family', () {
    test('absent blocks parse to null', () {
      final user = UserModel.fromCustomApi(_payload());
      expect(user.actingFor, isNull);
      expect(user.family, isNull);
    });

    test('acting_for is parsed with its scopes', () {
      final user = UserModel.fromCustomApi(_payload({
        'email': null,
        'acting_for': {
          'actor_user_id': 'guardian-1',
          'dependent_user_id': 'user-1',
          'guardianship_id': 'g-1',
          'consent_status': 'pending',
          'scopes': ['self:read', 'profile:write'],
        },
        'family': null,
      }));

      expect(user.actingFor?.actorUserId, 'guardian-1');
      expect(user.actingFor?.dependentUserId, 'user-1');
      expect(user.actingFor?.guardianshipId, 'g-1');
      expect(user.actingFor?.consentStatus, 'pending');
      expect(user.actingFor?.scopes, ['self:read', 'profile:write']);
      expect(user.family, isNull);
    });

    test('malformed acting_for is ignored', () {
      for (final value in <Object?>[
        'x',
        42,
        <dynamic>[],
        <String, dynamic>{},
        {'actor_user_id': 'a'},
        {'dependent_user_id': 'd'},
        {'actor_user_id': '', 'dependent_user_id': 'd'},
      ]) {
        final user = UserModel.fromCustomApi(_payload({'acting_for': value}));
        expect(user.actingFor, isNull, reason: '$value');
      }
    });

    test('family is parsed', () {
      final user = UserModel.fromCustomApi(_payload({
        'family': {'is_guardian': true, 'dependents_count': 2},
      }));
      expect(user.family?.isGuardian, isTrue);
      expect(user.family?.dependentsCount, 2);
    });

    test('malformed family degrades to safe defaults', () {
      final user = UserModel.fromCustomApi(_payload({
        'family': {'is_guardian': 'yes', 'dependents_count': 'many'},
      }));
      expect(user.family?.isGuardian, isFalse);
      expect(user.family?.dependentsCount, 0);

      final notAMap = UserModel.fromCustomApi(_payload({'family': 'x'}));
      expect(notAMap.family, isNull);
    });

    test('acting_for and family are never persisted by toJson', () {
      final user = UserModel.fromCustomApi(_payload({
        'acting_for': {
          'actor_user_id': 'guardian-1',
          'dependent_user_id': 'user-1',
        },
        'family': {'is_guardian': true, 'dependents_count': 1},
      }));
      final json = user.toJson();
      expect(json.containsKey('actingFor'), isFalse);
      expect(json.containsKey('acting_for'), isFalse);
      expect(json.containsKey('family'), isFalse);
      expect(UserModel.fromJson(json).actingFor, isNull);
    });

    test('they take part in equality so the router refreshes', () {
      final a = UserModel.fromCustomApi(_payload());
      final b = UserModel.fromCustomApi(_payload({
        'acting_for': {
          'actor_user_id': 'guardian-1',
          'dependent_user_id': 'user-1',
        },
      }));
      expect(a.actingFor, isNull);
      expect(b.actingFor, isNotNull);
      expect(a == b, isFalse);
    });
  });
}
