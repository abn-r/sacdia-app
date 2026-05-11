/// Widget tests for the persona-driven navigation shell (T-10/T-14).
///
/// These tests verify:
/// 1. Slot count per persona matches spec FR-2 (exactly 5 slots).
/// 2. Slot label keys are correct for Miembro and Director personas.
/// 3. NavigationBar renders the correct number of [NavigationDestination]s.
///
/// NOTE: [_MainShell] is a private class inside router.dart and cannot be
/// imported directly. Instead, we use a [_TestNavShell] widget that mirrors
/// its NavigationBar build path using the public [personaNavSlotsProvider],
/// which is the exact provider [_MainShell] consumes in production.
///
/// EasyLocalization is intentionally omitted from these tests. Labels are
/// rendered using the raw [NavSlot.labelKey] string so tests remain
/// deterministic without locale setup. Production correctness of translated
/// strings is covered by the i18n key tests in [persona_nav_config_test.dart].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/persona/index.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';

// ── Fake helpers ──────────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  final UserEntity? _user;
  _FakeAuthNotifier(this._user);

  @override
  Future<UserEntity?> build() async => _user;
}

class _FakeCountNotifier extends UnreadNotificationsCountNotifier {
  @override
  int build() => 0;
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

// ── Test shell widget ─────────────────────────────────────────────────────────

/// Mirrors the [NavigationBar] portion of [_MainShell] using the same provider.
///
/// Uses raw [NavSlot.labelKey] (not translated) so no locale setup is needed.
class _TestNavShell extends ConsumerWidget {
  const _TestNavShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(personaNavSlotsProvider);

    return Scaffold(
      body: const SizedBox.shrink(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        destinations: slots
            .map(
              (slot) => NavigationDestination(
                icon: NavBadge(
                  source: slot.badgeSource,
                  child: const Icon(Icons.circle),
                ),
                selectedIcon: NavBadge(
                  source: slot.badgeSource,
                  child: const Icon(Icons.circle),
                ),
                // Use raw labelKey for test stability (no locale needed)
                label: slot.labelKey,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Test harness ──────────────────────────────────────────────────────────────

Future<void> _pumpShell(
  WidgetTester tester, {
  required UserEntity? user,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
        unreadNotificationsCountProvider.overrideWith(
          () => _FakeCountNotifier(),
        ),
      ],
      child: const MaterialApp(
        home: _TestNavShell(),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('_MainShell navigation bar — persona slot count (T-10, T-14)', () {
    testWidgets('Miembro persona renders exactly 5 navigation destinations',
        (tester) async {
      await _pumpShell(tester, user: _userWithRole('member'));

      expect(
        find.byType(NavigationDestination),
        findsNWidgets(5),
        reason: 'Miembro nav must have exactly 5 slots (FR-2)',
      );
    });

    testWidgets('Director persona renders exactly 5 navigation destinations',
        (tester) async {
      await _pumpShell(tester, user: _userWithRole('director'));

      expect(
        find.byType(NavigationDestination),
        findsNWidgets(5),
        reason: 'Director nav must have exactly 5 slots (FR-2)',
      );
    });

    testWidgets('null user (no auth) renders Miembro nav — 5 destinations',
        (tester) async {
      await _pumpShell(tester, user: null);

      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('Consejero persona renders exactly 5 navigation destinations',
        (tester) async {
      await _pumpShell(tester, user: _userWithRole('counselor'));

      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('Tesorero persona renders exactly 5 navigation destinations',
        (tester) async {
      await _pumpShell(tester, user: _userWithRole('treasurer'));

      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });
  });

  group('_MainShell navigation bar — slot labels via labelKey (T-11)', () {
    testWidgets('Miembro: nav bar shows correct labelKey text for all 5 slots',
        (tester) async {
      await _pumpShell(tester, user: _userWithRole('member'));

      // Raw labelKey strings are used as labels in _TestNavShell
      expect(find.text('nav.dashboard'), findsWidgets);
      expect(find.text('nav.classes'), findsWidgets);
      expect(find.text('nav.activities'), findsWidgets);
      expect(find.text('nav.ranking'), findsWidgets);
      expect(find.text('nav.profile'), findsWidgets);
    });

    testWidgets('Director: nav bar shows correct labelKey text for all 5 slots',
        (tester) async {
      await _pumpShell(tester, user: _userWithRole('director'));

      expect(find.text('nav.members'), findsWidgets);
      expect(find.text('nav.club'), findsWidgets);
      expect(find.text('nav.finances'), findsWidgets);
      expect(find.text('nav.activities'), findsWidgets);
      expect(find.text('nav.profile'), findsWidgets);
    });

    testWidgets(
        'Consejero: nav bar shows correct labelKey text for all 5 slots',
        (tester) async {
      await _pumpShell(tester, user: _userWithRole('counselor'));

      expect(find.text('nav.my_unit'), findsWidgets);
      expect(find.text('nav.classes'), findsWidgets);
      expect(find.text('nav.members'), findsWidgets);
      expect(find.text('nav.activities'), findsWidgets);
      expect(find.text('nav.profile'), findsWidgets);
    });

    testWidgets(
        'Tesorero: nav bar shows correct labelKey text for all 5 slots',
        (tester) async {
      await _pumpShell(tester, user: _userWithRole('treasurer'));

      expect(find.text('nav.finances'), findsWidgets);
      expect(find.text('nav.insurance'), findsWidgets);
      expect(find.text('nav.club'), findsWidgets);
      expect(find.text('nav.activities'), findsWidgets);
      expect(find.text('nav.profile'), findsWidgets);
    });
  });

  group('_MainShell navigation bar — slot identity (T-11)', () {
    test('personaNavSlotsProvider for Director — correct slot label keys',
        () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider
              .overrideWith(() => _FakeAuthNotifier(_userWithRole('director'))),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      final slots = container.read(personaNavSlotsProvider);
      expect(slots.length, 5);
      expect(slots[0].labelKey, 'nav.members');
      expect(slots[1].labelKey, 'nav.club');
      expect(slots[2].labelKey, 'nav.finances');
      expect(slots[3].labelKey, 'nav.activities');
      expect(slots[4].labelKey, 'nav.profile');
    });

    test('personaNavSlotsProvider for Miembro — correct slot label keys',
        () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(_userWithRole('member')),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      final slots = container.read(personaNavSlotsProvider);
      expect(slots.length, 5);
      expect(slots[0].labelKey, 'nav.dashboard');
      expect(slots[1].labelKey, 'nav.classes');
      expect(slots[2].labelKey, 'nav.activities');
      expect(slots[3].labelKey, 'nav.ranking');
      expect(slots[4].labelKey, 'nav.profile');
    });
  });

  group('T-13: badgeSource wiring in persona_nav_config', () {
    test('Activities slot in every persona has badgeSource=activities', () {
      for (final entry in personaNavConfig.entries) {
        final activitiesSlot = entry.value.firstWhere(
          (s) => s.labelKey == 'nav.activities',
          orElse: () => throw StateError(
            'Persona ${entry.key} missing Activities slot',
          ),
        );
        expect(
          activitiesSlot.badgeSource,
          NavBadgeSource.activities,
          reason: 'Persona ${entry.key}: Activities slot must badge activities',
        );
      }
    });

    test('Consejero Mi Unidad slot has badgeSource=unit (FR-8)', () {
      final slots = personaNavConfig[Persona.consejero]!;
      final unitSlot = slots.firstWhere((s) => s.labelKey == 'nav.my_unit');
      expect(unitSlot.badgeSource, NavBadgeSource.unit);
    });

    test('Director Miembros slot has badgeSource=members (FR-8)', () {
      final slots = personaNavConfig[Persona.director]!;
      final membersSlot = slots.firstWhere((s) => s.labelKey == 'nav.members');
      expect(membersSlot.badgeSource, NavBadgeSource.members);
    });

    test('Tesorero Finanzas slot has badgeSource=finances (FR-8)', () {
      final slots = personaNavConfig[Persona.tesorero]!;
      final financesSlot =
          slots.firstWhere((s) => s.labelKey == 'nav.finances');
      expect(financesSlot.badgeSource, NavBadgeSource.finances);
    });

    test('Coordinador Hub slot has badgeSource=hub (FR-8)', () {
      final slots = personaNavConfig[Persona.coordinador]!;
      final hubSlot = slots.firstWhere((s) => s.labelKey == 'nav.hub');
      expect(hubSlot.badgeSource, NavBadgeSource.hub);
    });
  });
}
