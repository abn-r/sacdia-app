/// Tests for CoordinatorClubsListView (FR-2, branchIndex=1).
///
/// Tests:
/// 1. Smoke render: view renders without throwing when clubs data is empty.
/// 2. Loading state: skeleton placeholder is shown while loading.
/// 3. Error state: error widget and retry button are shown on failure.
/// 4. Data state: club cards are rendered for each club in the list.
/// 5. RBAC gating: coordinator persona resolves correctly (T-24 alignment).
/// 6. Router: coordinatorClubs route constant matches expected path.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/persona/index.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_club.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/coordinator_clubs_list_view.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';

// ── Fake auth helpers ─────────────────────────────────────────────────────────

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

UserEntity _coordinatorUser() {
  return UserEntity(
    id: 'coord-test-id',
    email: 'coord@test.com',
    postRegisterComplete: true,
    authorization: AuthorizationSnapshot(
      clubAssignments: [
        AuthorizationGrant(
          assignmentId: 'a1',
          roleName: 'coordinator',
          status: 'active',
        ),
      ],
      activeAssignmentId: 'a1',
    ),
  );
}

// ── Stub clubs ────────────────────────────────────────────────────────────────

final _stubClubs = [
  const CoordinatorClub(
      id: 1, name: 'Club Conquistadores Norte', localFieldId: 10),
  const CoordinatorClub(id: 2, name: 'Club Aventureros Sur', localFieldId: 10),
];

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pumpView(
  WidgetTester tester, {
  required AsyncValue<List<CoordinatorClub>> clubsState,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          () => _FakeAuthNotifier(_coordinatorUser()),
        ),
        unreadNotificationsCountProvider.overrideWith(
          () => _FakeCountNotifier(),
        ),
        // Override the raw clubs provider to control state in tests.
        coordinatorClubsRawProvider.overrideWith((ref) async {
          if (clubsState is AsyncData<List<CoordinatorClub>>) {
            return clubsState.value;
          }
          if (clubsState is AsyncError) {
            throw clubsState.error as Object;
          }
          // Loading: return a future that never resolves during test
          await Future<void>.delayed(const Duration(hours: 1));
          return [];
        }),
      ],
      child: const MaterialApp(
        home: CoordinatorClubsListView(),
      ),
    ),
  );
  // One frame to start loading, one more to settle non-deferred states
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Unit: RBAC gating ─────────────────────────────────────────────────────

  group('RBAC: coordinator persona resolves correctly', () {
    test('coordinator role maps to Persona.coordinador', () {
      final user = _coordinatorUser();
      final persona = resolvePersona(user.authorization);
      expect(persona, Persona.coordinador);
    });

    test('coordinatorClubs route is /coordinator/clubs', () {
      expect(RouteNames.coordinatorClubs, '/coordinator/clubs');
    });
  });

  // ── Widget: smoke render ──────────────────────────────────────────────────

  group('CoordinatorClubsListView smoke render', () {
    testWidgets('renders without throwing when data is empty list',
        (tester) async {
      await _pumpView(
        tester,
        clubsState: const AsyncData([]),
      );
      await tester.pumpAndSettle();

      // View renders — no exception thrown
      expect(find.byType(CoordinatorClubsListView), findsOneWidget);
    });

    testWidgets('shows loading skeleton while data is loading', (tester) async {
      // Use a delayed future that resolves quickly to avoid pending timer issues.
      // We just need to assert the skeleton is visible before settlement.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => _FakeAuthNotifier(_coordinatorUser()),
            ),
            unreadNotificationsCountProvider.overrideWith(
              () => _FakeCountNotifier(),
            ),
            coordinatorClubsRawProvider.overrideWith((ref) async {
              // Delay slightly so initial frame shows loading skeleton
              await Future<void>.delayed(Duration.zero);
              return [];
            }),
          ],
          child: const MaterialApp(home: CoordinatorClubsListView()),
        ),
      );
      // First frame: loading skeleton should be visible
      await tester.pump();

      // Loading state shows a ListView of skeleton containers
      expect(find.byType(ListView), findsWidgets);

      // Settle so the delayed future completes without leaking timers
      await tester.pumpAndSettle();
    });

    testWidgets('shows error state on failure', (tester) async {
      await _pumpView(
        tester,
        clubsState: AsyncError(
          Exception('network error'),
          StackTrace.empty,
        ),
      );
      await tester.pumpAndSettle();

      // Error icon or retry button should be present
      expect(
          find.byType(ElevatedButton).evaluate().isNotEmpty ||
              find.byType(TextButton).evaluate().isNotEmpty ||
              find.byIcon(Icons.refresh).evaluate().isNotEmpty ||
              find.text('Reintentar').evaluate().isNotEmpty ||
              find.text('Retry').evaluate().isNotEmpty,
          isTrue);
    });

    testWidgets('shows club cards when data is available', (tester) async {
      await _pumpView(
        tester,
        clubsState: AsyncData(_stubClubs),
      );
      await tester.pumpAndSettle();

      // Both clubs appear in the list
      expect(find.text('Club Conquistadores Norte'), findsOneWidget);
      expect(find.text('Club Aventureros Sur'), findsOneWidget);
    });
  });
}
