import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/data/models/user_model.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';

Map<String, dynamic> _me(Map<String, dynamic> authorization) => {
      'user_id': 'user-1',
      'email': 'user@example.com',
      'authorization': {
        'effective': {
          'permissions': ['clubs:read'],
        },
        'grants': {
          'global_roles': [
            {'role_name': 'coordinator', 'permissions': <String>[]},
          ],
          'club_assignments': <Map<String, dynamic>>[],
        },
        'active_assignment': null,
        ...authorization,
      },
    };

void main() {
  group('UserModel authorization (phase 7)', () {
    test('parses capabilities (sorted, normalised), territory and roles', () {
      final user = UserModel.fromCustomApi(_me({
        'capabilities': ['coordination.hub_view', ' Club.Staff_Mode ', ''],
        'territory': {
          'level': 'local_field',
          'division_id': 1,
          'union_id': '7',
          'local_field_id': 12,
        },
        'assignable_global_roles': ['pastor', 'coordinator'],
      }));

      final authorization = user.authorization!;
      expect(
        authorization.capabilities,
        ['club.staff_mode', 'coordination.hub_view'],
      );
      expect(authorization.hasCapability('coordination.hub_view'), isTrue);
      expect(authorization.hasCapability('CLUB.STAFF_MODE'), isTrue);
      expect(authorization.hasCapability('units.manage'), isFalse);
      expect(
        authorization.territory,
        const AuthorizationTerritory(
          level: 'local_field',
          divisionId: 1,
          unionId: 7,
          localFieldId: 12,
        ),
      );
      expect(authorization.assignableGlobalRoles, ['pastor', 'coordinator']);
      expect(user.authorizationStale, isFalse);
    });

    test('an older server (no capabilities) yields an empty list: deny', () {
      final user = UserModel.fromCustomApi(_me({}));
      final authorization = user.authorization!;
      expect(authorization.capabilities, isEmpty);
      expect(authorization.territory, isNull);
      expect(authorization.assignableGlobalRoles, isEmpty);
      expect(authorization.hasCapability('coordination.hub_view'), isFalse);
    });

    test('a malformed territory or one without level is null', () {
      expect(
        UserModel.fromCustomApi(_me({'territory': 'all'}))
            .authorization!
            .territory,
        isNull,
      );
      expect(
        UserModel.fromCustomApi(_me({
          'territory': {'division_id': 1},
        })).authorization!.territory,
        isNull,
      );
      expect(
        UserModel.fromCustomApi(_me({
          'territory': {'level': 'all', 'division_id': null},
        })).authorization!.territory,
        const AuthorizationTerritory(level: 'all'),
      );
    });

    test('toJson/fromJson keeps capabilities, territory and roles', () {
      final user = UserModel.fromCustomApi(_me({
        'capabilities': ['coordination.hub_view'],
        'territory': {'level': 'union', 'union_id': 3},
        'assignable_global_roles': ['pastor'],
      }));

      final restored = UserModel.fromJson(user.toJson());

      expect(restored.authorization, user.authorization);
      expect(restored.authorization!.capabilities, ['coordination.hub_view']);
      expect(restored.authorization!.territory!.unionId, 3);
      expect(restored.authorization!.assignableGlobalRoles, ['pastor']);
    });

    test('capabilities, territory and the stale flag take part in equality',
        () {
      const base = AuthorizationSnapshot(capabilities: ['units.manage']);
      expect(
        base,
        isNot(const AuthorizationSnapshot(capabilities: ['club.staff_mode'])),
      );
      expect(
        base,
        isNot(const AuthorizationSnapshot(
          capabilities: ['units.manage'],
          territory: AuthorizationTerritory(level: 'all'),
        )),
      );
      const stale = UserModel(id: 'u', authorizationStale: true);
      expect(stale, isNot(const UserModel(id: 'u')));
      expect(
          stale.copyWith(authorizationStale: false), const UserModel(id: 'u'));
    });
  });
}
