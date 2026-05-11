import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/club_role_names.dart';
import 'package:sacdia_app/core/persona/persona.dart';
import 'package:sacdia_app/core/persona/persona_resolver.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';

/// Builds a [AuthorizationSnapshot] with a single active club assignment
/// using the given [roleName].
AuthorizationSnapshot _snapshotWithActiveRole(String roleName) {
  return AuthorizationSnapshot(
    clubAssignments: [
      AuthorizationGrant(
        assignmentId: 'assignment-1',
        roleName: roleName,
        status: 'active',
      ),
    ],
    activeAssignmentId: 'assignment-1',
  );
}

/// Builds a [AuthorizationSnapshot] with global grants only (no active club).
AuthorizationSnapshot _snapshotWithGlobalRole(String roleName) {
  return AuthorizationSnapshot(
    globalGrants: [
      AuthorizationGrant(
        assignmentId: 'global-1',
        roleName: roleName,
        status: 'active',
      ),
    ],
  );
}

void main() {
  group('resolvePersona — active grant role mapping (FR-1)', () {
    test('member → Persona.miembro', () {
      expect(
        resolvePersona(_snapshotWithActiveRole(ClubRoleNames.member)),
        Persona.miembro,
      );
    });

    test('counselor → Persona.consejero', () {
      expect(
        resolvePersona(_snapshotWithActiveRole(ClubRoleNames.counselor)),
        Persona.consejero,
      );
    });

    test('director → Persona.director', () {
      expect(
        resolvePersona(_snapshotWithActiveRole(ClubRoleNames.director)),
        Persona.director,
      );
    });

    test('deputy-director → Persona.director (S-14 analogue)', () {
      expect(
        resolvePersona(_snapshotWithActiveRole(ClubRoleNames.deputyDirector)),
        Persona.director,
      );
    });

    test('secretary → Persona.director', () {
      expect(
        resolvePersona(_snapshotWithActiveRole(ClubRoleNames.secretary)),
        Persona.director,
      );
    });

    test('secretary-treasurer → Persona.director (S-14)', () {
      expect(
        resolvePersona(
            _snapshotWithActiveRole(ClubRoleNames.secretaryTreasurer)),
        Persona.director,
      );
    });

    test('treasurer → Persona.tesorero', () {
      expect(
        resolvePersona(_snapshotWithActiveRole(ClubRoleNames.treasurer)),
        Persona.tesorero,
      );
    });
  });

  group(
      'resolvePersona — global role mapping (FR-9 fallback when active is null)',
      () {
    test('coordinator global role → Persona.coordinador', () {
      expect(
        resolvePersona(_snapshotWithGlobalRole('coordinator')),
        Persona.coordinador,
      );
    });

    test('admin global role → Persona.coordinador', () {
      expect(
        resolvePersona(_snapshotWithGlobalRole('admin')),
        Persona.coordinador,
      );
    });

    test('super-admin global role → Persona.coordinador', () {
      expect(
        resolvePersona(_snapshotWithGlobalRole('super-admin')),
        Persona.coordinador,
      );
    });

    test('assistant-admin global role → Persona.coordinador', () {
      expect(
        resolvePersona(_snapshotWithGlobalRole('assistant-admin')),
        Persona.coordinador,
      );
    });
  });

  group('resolvePersona — fallback cases (FR-10, S-13)', () {
    test('null snapshot → Persona.miembro', () {
      expect(resolvePersona(null), Persona.miembro);
    });

    test('empty snapshot (no grants, no active) → Persona.miembro', () {
      expect(
        resolvePersona(const AuthorizationSnapshot()),
        Persona.miembro,
      );
    });

    test(
        'snapshot with null activeGrant and empty globalGrants → Persona.miembro',
        () {
      expect(
        resolvePersona(
          const AuthorizationSnapshot(
            clubAssignments: [],
            globalGrants: [],
          ),
        ),
        Persona.miembro,
      );
    });

    test('unrecognised role → Persona.miembro (graceful fallback)', () {
      expect(
        resolvePersona(_snapshotWithActiveRole('unknown-future-role')),
        Persona.miembro,
      );
    });
  });

  group('resolvePersona — precedence in global grants (FR-1)', () {
    test('coordinator beats admin when both are global grants', () {
      final snapshot = AuthorizationSnapshot(
        globalGrants: [
          const AuthorizationGrant(roleName: 'admin', assignmentId: 'g1'),
          const AuthorizationGrant(roleName: 'coordinator', assignmentId: 'g2'),
        ],
      );
      expect(resolvePersona(snapshot), Persona.coordinador);
    });

    test('treasurer beats counselor when both are global grants', () {
      final snapshot = AuthorizationSnapshot(
        globalGrants: [
          const AuthorizationGrant(roleName: 'counselor', assignmentId: 'g1'),
          const AuthorizationGrant(roleName: 'treasurer', assignmentId: 'g2'),
        ],
      );
      expect(resolvePersona(snapshot), Persona.tesorero);
    });
  });

  // ── T-33: CI guard ─────────────────────────────────────────────────────────
  // Asserts that every ClubRoleNames constant maps to a non-miembro Persona,
  // except 'member' which maps to miembro.
  // If a new role is added to ClubRoleNames without updating _roleToPersona,
  // this test fails and blocks CI.
  group('T-33 — ClubRoleNames exhaustive mapping guard (R1 mitigation)', () {
    const knownClubRoles = [
      ClubRoleNames.director,
      ClubRoleNames.deputyDirector,
      ClubRoleNames.secretary,
      ClubRoleNames.treasurer,
      ClubRoleNames.secretaryTreasurer,
      ClubRoleNames.counselor,
      ClubRoleNames.member,
    ];

    for (final role in knownClubRoles) {
      test('ClubRoleNames.$role resolves to a known Persona', () {
        final persona = resolvePersona(_snapshotWithActiveRole(role));
        // All known club roles must resolve to something — none should be an
        // accidental fallback to miembro EXCEPT for 'member' itself.
        if (role == ClubRoleNames.member) {
          expect(persona, Persona.miembro,
              reason: 'member role must map to miembro');
        } else {
          expect(
            persona,
            isNot(Persona.miembro),
            reason:
                'Role "$role" fell through to Persona.miembro — update _roleToPersona in persona_resolver.dart',
          );
        }
      });
    }
  });
}
