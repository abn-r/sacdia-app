/// S-15 integration test: persona-nav context switch triggers shell swap.
///
/// Acceptance scenario (S-15, PR-4 verify report):
///   Boot as director → main shell renders director nav slots (Miembros first).
///   Switch activeAssignmentId to coordinator assignment → currentPersonaProvider
///   resolves to Persona.coordinador → nav slots rebuild to coordinator config
///   (Hub first, branchIndex 0–4).
///
/// Architecture note:
///   This test exercises the live Riverpod provider graph: authNotifierProvider
///   → currentPersonaProvider → personaNavSlotsProvider. The widget layer is a
///   _TestNavShell that mirrors the NavigationBar build path used in the real
///   _MainShell and _CoordinatorShell (same pattern as existing widget tests).
///
/// Headless execution:
///   Runs with IntegrationTestWidgetsFlutterBinding in pure host-mode.
///   No real device is required. No platform channels are invoked.
///   Run with: flutter test integration_test/persona_nav_context_switch_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sacdia_app/core/persona/index.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';

// ── Fake notifiers ────────────────────────────────────────────────────────────

/// Overridable AuthNotifier that exposes a [setUser] mutator so the test can
/// simulate a context switch without touching real secure storage or network.
class _MutableAuthNotifier extends AuthNotifier {
  UserEntity? _user;

  _MutableAuthNotifier(this._user);

  @override
  Future<UserEntity?> build() async => _user;

  /// Simulate a persona/context switch by replacing the user snapshot and
  /// re-emitting. Mirrors the effect of AuthNotifier.switchContext() which
  /// builds a new UserEntity with an updated activeAssignmentId.
  void setUser(UserEntity? user) {
    _user = user;
    state = AsyncData(user);
  }
}

class _FakeCountNotifier extends UnreadNotificationsCountNotifier {
  @override
  int build() => 0;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a [UserEntity] with a single [AuthorizationGrant] for [roleName].
UserEntity _userWith(String roleName, {String assignmentId = 'a1'}) {
  return UserEntity(
    id: 'test-$roleName',
    email: 'test@sacdia.app',
    postRegisterComplete: true,
    authorization: AuthorizationSnapshot(
      clubAssignments: [
        AuthorizationGrant(
          assignmentId: assignmentId,
          roleName: roleName,
          status: 'active',
        ),
      ],
      activeAssignmentId: assignmentId,
    ),
  );
}

/// Mirrors the NavigationBar portion of _MainShell / _CoordinatorShell.
///
/// Reads [personaNavSlotsProvider] — the same provider the production shells
/// consume — so slot rebuilds are exercised through the live provider graph.
/// Uses raw [NavSlot.labelKey] strings as labels (no locale setup needed).
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
                label: slot.labelKey,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Test entry point ──────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('S-15: persona-nav context switch — shell swap (integration)', () {
    late _MutableAuthNotifier authNotifier;

    setUp(() {
      authNotifier = _MutableAuthNotifier(_userWith('director'));
    });

    testWidgets(
      'director nav → coordinator nav on activeAssignmentId switch',
      (tester) async {
        // ── Phase 1: boot as director ─────────────────────────────────────
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authNotifierProvider.overrideWith(() => authNotifier),
              unreadNotificationsCountProvider.overrideWith(
                () => _FakeCountNotifier(),
              ),
            ],
            child: const MaterialApp(home: _TestNavShell()),
          ),
        );
        await tester.pumpAndSettle();

        // Director shell: first slot is Miembros (nav.members), 5 destinations.
        expect(
          find.byType(NavigationDestination),
          findsNWidgets(5),
          reason: 'Director nav must have exactly 5 slots (FR-2)',
        );
        expect(
          find.text('nav.members'),
          findsWidgets,
          reason: 'Director first slot must be Miembros (nav.members)',
        );
        // Coordinator Hub label must NOT be visible in director shell.
        expect(
          find.text('nav.hub'),
          findsNothing,
          reason: 'Director shell must NOT show coordinator Hub slot',
        );

        // ── Phase 2: context switch to coordinator ────────────────────────
        // Simulate AuthNotifier.switchContext(): emit a new UserEntity with
        // coordinator role. currentPersonaProvider reacts → slots rebuild.
        authNotifier.setUser(_userWith('coordinator', assignmentId: 'coord-1'));

        // One pump propagates the state change through the provider graph.
        // pumpAndSettle ensures all reactive rebuilds complete.
        await tester.pump();
        await tester.pumpAndSettle();

        // Coordinator shell: 5 slots, first is Hub (nav.hub).
        expect(
          find.byType(NavigationDestination),
          findsNWidgets(5),
          reason: 'Coordinator nav must have exactly 5 slots (FR-2)',
        );
        expect(
          find.text('nav.hub'),
          findsWidgets,
          reason: 'Coordinator first slot must be Hub (nav.hub) after switch',
        );
        // Miembros label must NOT be visible in coordinator shell.
        expect(
          find.text('nav.members'),
          findsNothing,
          reason: 'Coordinator shell must NOT show main-shell Miembros slot',
        );

        // Verify all 5 coordinator slot keys are present.
        expect(find.text('nav.clubs'), findsWidgets);
        expect(find.text('nav.reports'), findsWidgets);
        expect(find.text('nav.activities'), findsWidgets);
        expect(find.text('nav.profile'), findsWidgets);
      },
    );
  });
}
