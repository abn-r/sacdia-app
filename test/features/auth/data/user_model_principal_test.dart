import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/data/models/user_model.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';

Map<String, dynamic> _payload([Map<String, dynamic>? extra]) => {
      'user_id': 'user-1',
      'email': 'user@example.com',
      ...?extra,
    };

Map<String, dynamic> _teenPrincipal({
  String status = 'pending_guardian',
  Object? pendingSince = '2026-10-01T00:00:00.000Z',
  Object? daysLeft,
}) =>
    {
      'kind': 'supervised_user',
      'scopes': ['self:read', 'profile:write'],
      'supervision': {
        'status': status,
        'pending_since': pendingSince,
        'guardians': [
          {'display_name': 'María Pérez', 'relationship_type_name': 'Madre'},
        ],
        'summary_visible_to_guardians': true,
        if (daysLeft != null) 'days_left': daysLeft,
      },
    };

class UserEntityFixture {
  static UserEntity withPrincipal(PrincipalInfo p) =>
      UserEntity(id: 'u', principal: p);
}

void main() {
  group('absent blocks fail closed', () {
    test('no principal / features / analytics field', () {
      final user = UserModel.fromCustomApi(_payload());
      expect(user.principal, isNull);
      expect(user.familyFeatures, isNull);
      expect(user.analyticsAnonymous, isNull);
      expect(user.serverMode, isNull);
      expect(user.mode, AccountMode.adult);
      // Sin el campo explícito la analítica se queda anónima.
      expect(user.canIdentifyInAnalytics, isFalse);
    });

    test('a malformed principal is ignored', () {
      for (final bad in <Object?>['supervised_user', 42, <int>[]]) {
        final user = UserModel.fromCustomApi(_payload({'principal': bad}));
        expect(user.principal, isNull, reason: '$bad');
      }
    });

    test('an unknown kind is kept as unknown and never identifies', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': {'kind': 'hologram'},
        'analytics_anonymous': false,
      }));
      expect(user.principal!.kind, PrincipalKind.unknown);
      expect(user.canIdentifyInAnalytics, isFalse);
    });
  });

  group('age unknown (no birthday, post-registration incomplete)', () {
    Map<String, dynamic> payload() => _payload({
          'mode': 'profile_incomplete',
          'principal': {
            'kind': 'age_unknown_user',
            'scopes': ['account:manage', 'profile:write'],
            'supervision': null,
          },
          'family': null,
          'analytics_anonymous': true,
        });

    test('parses the kind and the mode', () {
      final user = UserModel.fromCustomApi(payload());
      expect(user.principal!.kind, PrincipalKind.ageUnknownUser);
      expect(user.principal!.supervision, isNull);
      expect(user.serverMode, AccountMode.profileIncomplete);
      expect(user.mode, AccountMode.profileIncomplete);
      expect(user.family, isNull);
    });

    test('is not an adult, not a teen, and has no family features', () {
      final user = UserModel.fromCustomApi(payload());
      expect(user.isSupervisedTeen, isFalse);
      expect(user.isRestrictedAccount, isTrue);
      expect(user.isLimitedAccount, isTrue);
    });

    test('analytics stay anonymous even if analytics_anonymous were false', () {
      final data = payload()..['analytics_anonymous'] = false;
      expect(UserModel.fromCustomApi(data).canIdentifyInAnalytics, isFalse);
    });

    test('the kind alone is enough: a missing mode still fails closed', () {
      final data = payload()..remove('mode');
      expect(
        UserModel.fromCustomApi(data).mode,
        AccountMode.profileIncomplete,
      );
    });

    test('the login shape (kind only, no mode) is restricted too', () {
      final p = UserModel.parsePrincipal(
        {'kind': 'age_unknown_user', 'supervision': null},
      )!;
      expect(
        UserEntityFixture.withPrincipal(p).mode,
        AccountMode.profileIncomplete,
      );
    });

    test('a server saying adult cannot override the age-unknown kind', () {
      final data = payload()..['mode'] = 'adult';
      expect(
        UserModel.fromCustomApi(data).mode,
        AccountMode.profileIncomplete,
      );
    });
  });

  group('unknown principal kinds fail closed', () {
    test('an unknown kind is restricted, never adult, even if mode says adult',
        () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': {'kind': 'hologram'},
        'mode': 'adult',
        'analytics_anonymous': false,
      }));
      expect(user.mode, AccountMode.restricted);
      expect(user.isRestrictedAccount, isTrue);
      expect(user.canIdentifyInAnalytics, isFalse);
    });

    test('a principal without a kind is restricted', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': {'scopes': <String>[]},
      }));
      expect(user.mode, AccountMode.restricted);
    });

    test('a known adult is not restricted', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': {'kind': 'user'},
        'mode': 'adult',
        'analytics_anonymous': false,
      }));
      expect(user.mode, AccountMode.adult);
      expect(user.isLimitedAccount, isFalse);
      expect(user.canIdentifyInAnalytics, isTrue);
    });
  });

  group('adult', () {
    test('explicit analytics_anonymous=false is the only way to identify', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': {'kind': 'user', 'scopes': null, 'supervision': null},
        'analytics_anonymous': false,
        'mode': 'adult',
        'family_features': {
          'teen_login': true,
          'linked_device': false,
          'director_create_minor': false,
        },
      }));
      expect(user.principal!.kind, PrincipalKind.user);
      expect(user.principal!.scopes, isNull);
      expect(user.principal!.supervision, isNull);
      expect(user.mode, AccountMode.adult);
      expect(user.canIdentifyInAnalytics, isTrue);
      expect(user.familyFeatures!.teenLogin, isTrue);
      expect(user.familyFeatures!.linkedDevice, isFalse);
    });

    test('analytics_anonymous=true blocks identify', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': {'kind': 'user'},
        'analytics_anonymous': true,
      }));
      expect(user.canIdentifyInAnalytics, isFalse);
    });

    test('a non-boolean analytics_anonymous counts as absent', () {
      for (final raw in <Object?>['false', 0, 'no']) {
        final user = UserModel.fromCustomApi(_payload({
          'principal': {'kind': 'user'},
          'analytics_anonymous': raw,
        }));
        expect(user.analyticsAnonymous, isNull, reason: '$raw');
        expect(user.canIdentifyInAnalytics, isFalse, reason: '$raw');
      }
    });

    test('analytics_anonymous nested in principal is also read', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': {'kind': 'user', 'analytics_anonymous': false},
      }));
      expect(user.analyticsAnonymous, isFalse);
    });
  });

  group('teen pending', () {
    test('parses supervision, guardians and pending_since', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': _teenPrincipal(),
        'analytics_anonymous': true,
      }));
      final p = user.principal!;
      expect(p.kind, PrincipalKind.supervisedUser);
      expect(p.scopes, ['self:read', 'profile:write']);
      expect(p.supervision!.status, SupervisionStatus.pendingGuardian);
      expect(p.supervision!.pendingSince, DateTime.utc(2026, 10, 1));
      expect(p.supervision!.guardians.single.displayName, 'María Pérez');
      expect(p.supervision!.guardians.single.relationshipTypeName, 'Madre');
      expect(user.mode, AccountMode.teenPending);
      expect(user.isSupervisedTeen, isTrue);
      expect(user.canIdentifyInAnalytics, isFalse);
    });

    test('days_left is computed from pending_since when the server omits it',
        () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': _teenPrincipal(),
      }));
      final s = user.principal!.supervision!;
      expect(s.daysLeftAt(DateTime.utc(2026, 10, 1)), 90);
      expect(s.daysLeftAt(DateTime.utc(2026, 10, 11, 5)), 80);
      expect(s.daysLeftAt(DateTime.utc(2027, 3, 1)), 0);
    });

    test('a server days_left wins over the computed value', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': _teenPrincipal(daysLeft: 12),
      }));
      expect(
        user.principal!.supervision!.daysLeftAt(DateTime.utc(2026, 10, 2)),
        12,
      );
    });

    test('no clock without a start date or a server value', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': _teenPrincipal(pendingSince: null),
      }));
      expect(
        user.principal!.supervision!.daysLeftAt(DateTime.utc(2026, 10, 2)),
        isNull,
      );
    });

    test('contact data is never parsed from guardians', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': {
          'kind': 'supervised_user',
          'supervision': {
            'status': 'pending_guardian',
            'guardians': [
              {
                'display_name': 'María',
                'email': 'maria@example.com',
                'phone': '555',
              },
            ],
          },
        },
      }));
      final guardian = user.principal!.supervision!.guardians.single;
      expect(guardian.props, ['María', null, null, null]);
    });
  });

  group('teen supervised', () {
    test('active supervision is teen_supervised', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': _teenPrincipal(status: 'active'),
      }));
      expect(user.mode, AccountMode.teenSupervised);
      expect(user.principal!.supervision!.daysLeftAt(DateTime.utc(2026, 10, 5)),
          isNull);
    });

    test('a supervised principal with an unreadable status is pending', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': {'kind': 'supervised_user', 'supervision': null},
      }));
      expect(user.mode, AccountMode.teenPending);
    });

    test('an explicit server mode wins over the principal', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': _teenPrincipal(),
        'mode': 'teen_supervised',
      }));
      expect(user.mode, AccountMode.teenSupervised);
    });

    test('an unknown server mode fails closed as restricted, never adult', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': _teenPrincipal(),
        'mode': 'robot',
      }));
      expect(user.mode, AccountMode.restricted);
      expect(user.canIdentifyInAnalytics, isFalse);
    });
  });

  group('login payload shape', () {
    test('supervision as a bare status string', () {
      final p = UserModel.parsePrincipal(
        {'kind': 'supervised_user', 'supervision': 'active'},
      )!;
      expect(p.supervision!.status, SupervisionStatus.active);
      expect(p.supervision!.guardians, isEmpty);
    });

    test('supervision null for a plain user', () {
      final p = UserModel.parsePrincipal(
        {'kind': 'user', 'supervision': null},
      )!;
      expect(p.kind, PrincipalKind.user);
      expect(p.supervision, isNull);
    });
  });

  test('copyWith carries the new fields', () {
    final user = UserModel.fromCustomApi(_payload({
      'principal': _teenPrincipal(),
      'analytics_anonymous': true,
    }));
    final copy = user.copyWith(name: 'Ana');
    expect(copy.principal, user.principal);
    expect(copy.analyticsAnonymous, isTrue);
  });
}
