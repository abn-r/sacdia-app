import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/authorization/access_subject.dart';
import 'package:sacdia_app/core/authorization/catalog_dump.dart';
import 'package:sacdia_app/core/authorization/evaluate_access.dart';
import 'package:sacdia_app/core/authorization/screen_catalog.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import '../../support/capability_fixtures.dart';

UserEntity _user({
  List<String> permissions = const [],
  List<String> roles = const [],
  String? activeClubRole,
  List<String>? capabilities,
}) {
  return UserEntity(
    id: 'actor',
    email: 'actor@example.com',
    authorization: AuthorizationSnapshot(
      effectivePermissions: permissions,
      globalGrants: [
        for (final role in roles) AuthorizationGrant(roleName: role),
      ],
      clubAssignments: [
        if (activeClubRole != null)
          AuthorizationGrant(
            assignmentId: 'a1',
            roleName: activeClubRole,
            status: 'active',
          ),
      ],
      activeAssignmentId: activeClubRole != null ? 'a1' : null,
      // Lo que el backend publicaría para esos roles (fixture), salvo que el
      // test fije las capacidades a mano.
      capabilities: capabilities ??
          capabilitiesFor(globalRoles: roles, activeClubRole: activeClubRole),
    ),
  );
}

void main() {
  group('evaluateAccess', () {
    test('super-admin bypasses empty permissions', () {
      final subject = subjectFromUser(_user(roles: ['super-admin']));
      expect(
        evaluateAccess(
          subject,
          const CapabilityGate(permissions: ['finances:read']),
        ),
        isTrue,
      );
    });

    test('expands coordinator aliases', () {
      final subject = subjectFromUser(_user(roles: ['zone-coordinator']));
      expect(canViewScreen(subject, 'coordinator-hub'), isTrue);
    });

    test('opens coordinator hub for director-lf via coordinator alias', () {
      final subject = subjectFromUser(
        _user(permissions: ['coordination:manage'], roles: ['director-lf']),
      );
      expect(canViewScreen(subject, 'coordinator-hub'), isTrue);
    });

    test('opens members with users:read_detail and no field role', () {
      final subject = subjectFromUser(
        _user(permissions: ['users:read_detail']),
      );
      expect(canViewScreen(subject, 'app-members'), isTrue);
    });

    test('unknown screen is deny', () {
      final subject =
          subjectFromUser(_user(permissions: ['users:read_detail']));
      expect(canViewScreen(subject, 'does-not-exist'), isFalse);
    });
  });

  group('investiture screens', () {
    test('app-section-investiture opens for the investiture board only', () {
      for (final role in ['director', 'secretary', 'secretary-treasurer']) {
        expect(
          canViewScreen(subjectFromUser(_user(activeClubRole: role)),
              'app-section-investiture'),
          isTrue,
          reason: role,
        );
      }
      for (final role in ['deputy-director', 'counselor', 'treasurer']) {
        expect(
          canViewScreen(subjectFromUser(_user(activeClubRole: role)),
              'app-section-investiture'),
          isFalse,
          reason: role,
        );
      }
      expect(
        canViewScreen(subjectFromUser(_user()), 'app-section-investiture'),
        isFalse,
      );
    });

    test('the board gate is the capability, never the role name', () {
      // Mismo rol, sin capacidad (servidor anterior a la fase 7): deny.
      expect(
        canViewScreen(
          subjectFromUser(_user(activeClubRole: 'director', capabilities: [])),
          'app-section-investiture',
        ),
        isFalse,
      );
      // Capacidad sin rol conocido: allow (el servidor decidió).
      expect(
        canViewScreen(
          subjectFromUser(_user(capabilities: ['investiture.board'])),
          'app-section-investiture',
        ),
        isTrue,
      );
    });

    test('a capability gate also requires its permissions', () {
      final subject = subjectFromUser(
        _user(capabilities: ['coordination.hub_view']),
      );
      expect(
        evaluateAccess(
          subject,
          const CapabilityGate(
            permissions: ['coordination:manage'],
            capability: 'coordination.hub_view',
          ),
        ),
        isFalse,
      );
      expect(
        evaluateAccess(
          subjectFromUser(_user(
            permissions: ['coordination:manage'],
            capabilities: ['coordination.hub_view'],
          )),
          const CapabilityGate(
            permissions: ['coordination:manage'],
            capability: 'coordination.hub_view',
          ),
        ),
        isTrue,
      );
    });

    test(
        'app-investiture-authorizer opens for pastor, director-lf, assistant-lf',
        () {
      for (final role in ['pastor', 'director-lf', 'assistant-lf']) {
        expect(
          canViewScreen(subjectFromUser(_user(roles: [role])),
              'app-investiture-authorizer'),
          isTrue,
          reason: role,
        );
      }
      for (final role in [
        'director',
        'secretary',
        'counselor',
        'user',
        'director-union',
        'admin',
      ]) {
        expect(
          canViewScreen(subjectFromUser(_user(roles: [role])),
              'app-investiture-authorizer'),
          isFalse,
          reason: role,
        );
      }
    });
  });

  group('catalog dump parity', () {
    test('matches the committed fixture from TS', () {
      final fixtureFile = File('test/fixtures/screen-catalog.snapshot.json');
      expect(fixtureFile.existsSync(), isTrue);
      final fixture = jsonDecode(fixtureFile.readAsStringSync());
      final dump = jsonDecode(jsonEncode(dumpAppCatalog()));
      expect(dump, fixture);
    });
  });
}
