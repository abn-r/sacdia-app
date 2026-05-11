import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/persona/nav_slot.dart';
import 'package:sacdia_app/core/persona/persona.dart';
import 'package:sacdia_app/core/persona/persona_providers.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

// ── Fake helpers ──────────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  final UserEntity? _user;
  _FakeAuthNotifier(this._user);

  @override
  Future<UserEntity?> build() async => _user;
}

UserEntity _userWithRole(String roleName) {
  return UserEntity(
    id: 'test-id',
    email: 'test@example.com',
    postRegisterComplete: true,
    authorization: AuthorizationSnapshot(
      clubAssignments: [
        AuthorizationGrant(
          assignmentId: 'a1',
          roleName: roleName,
          status: 'active',
        ),
      ],
      activeAssignmentId: 'a1',
    ),
  );
}

Future<ProviderContainer> _makeContainer(UserEntity? user) async {
  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
    ],
  );
  await container.read(authNotifierProvider.future);
  return container;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('currentPersonaProvider (T-07)', () {
    test('null auth → Persona.miembro', () async {
      final container = await _makeContainer(null);
      addTearDown(container.dispose);

      expect(container.read(currentPersonaProvider), Persona.miembro);
    });

    test('member auth → Persona.miembro', () async {
      final container = await _makeContainer(_userWithRole('member'));
      addTearDown(container.dispose);

      expect(container.read(currentPersonaProvider), Persona.miembro);
    });

    test('director auth → Persona.director', () async {
      final container = await _makeContainer(_userWithRole('director'));
      addTearDown(container.dispose);

      expect(container.read(currentPersonaProvider), Persona.director);
    });

    test('counselor auth → Persona.consejero', () async {
      final container = await _makeContainer(_userWithRole('counselor'));
      addTearDown(container.dispose);

      expect(container.read(currentPersonaProvider), Persona.consejero);
    });

    test('treasurer auth → Persona.tesorero', () async {
      final container = await _makeContainer(_userWithRole('treasurer'));
      addTearDown(container.dispose);

      expect(container.read(currentPersonaProvider), Persona.tesorero);
    });

    test('coordinator auth → Persona.coordinador', () async {
      final container = await _makeContainer(_userWithRole('coordinator'));
      addTearDown(container.dispose);

      expect(container.read(currentPersonaProvider), Persona.coordinador);
    });
  });

  group('personaNavSlotsProvider (T-07)', () {
    test('null auth → miembro nav config (5 slots)', () async {
      final container = await _makeContainer(null);
      addTearDown(container.dispose);

      final slots = container.read(personaNavSlotsProvider);
      expect(slots.length, 5);
    });

    test('member auth → miembro nav (5 slots)', () async {
      final container = await _makeContainer(_userWithRole('member'));
      addTearDown(container.dispose);

      final slots = container.read(personaNavSlotsProvider);
      expect(slots.length, 5);
    });

    test('director auth → director nav (5 slots, first slot = Miembros)',
        () async {
      final container = await _makeContainer(_userWithRole('director'));
      addTearDown(container.dispose);

      final slots = container.read(personaNavSlotsProvider);
      expect(slots.length, 5);
      expect(slots.first.labelKey, 'nav.members');
    });

    test(
        'every persona nav config has Activities slot with badgeSource=activities',
        () async {
      for (final role in [
        'member',
        'counselor',
        'director',
        'treasurer',
        'coordinator'
      ]) {
        final container = await _makeContainer(_userWithRole(role));
        addTearDown(container.dispose);

        final slots = container.read(personaNavSlotsProvider);
        final hasActivities = slots.any(
          (s) => s.badgeSource == NavBadgeSource.activities,
        );
        expect(
          hasActivities,
          isTrue,
          reason:
              'role=$role: nav must have Activities slot with badgeSource=activities',
        );
      }
    });
  });
}
