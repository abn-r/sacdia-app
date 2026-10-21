/// The "Fichas por verificar" entry of the coordinator hub shows only for a
/// user who holds `consent:verify` AND has sections in the coordination scope.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_scope.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/sla_dashboard.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/coordinator_hub_view.dart';

import '../../coordinator_test_support.dart';

class _FakeAuth extends AuthNotifier {
  _FakeAuth(this._permissions);

  final List<String> _permissions;

  @override
  Future<UserEntity?> build() async => UserEntity(
        id: 'coord-1',
        email: 'coord@test.com',
        name: 'Carlos',
        postRegisterComplete: true,
        authorization: AuthorizationSnapshot(
          effectivePermissions: _permissions,
        ),
      );
}

const _sla = SlaDashboard(
  investiture: SlaStat(pending: 0, avgDays: 0, overdue: 0),
  evidence: SlaStat(pending: 1, avgDays: 0, overdue: 0),
  camporee: SlaStat(pending: 0, avgDays: 0, overdue: 0),
  throughput: [],
  pipeline: [],
);

const _withSections = CoordinatorScope(
  isCoordinator: true,
  clubSectionIds: [2],
  sections: [CoordinatorSectionScope(clubSectionId: 2, clubTypeId: 1)],
);

const _noSections = CoordinatorScope(isCoordinator: false);

Future<GoRouter> _pumpHub(
  WidgetTester tester, {
  required List<String> permissions,
  required CoordinatorScope scope,
  FakeCoordinatorRepository? repo,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const CoordinatorHubView(),
      ),
      GoRoute(
        path: RouteNames.coordinatorConsentReview,
        builder: (_, __) => const Scaffold(body: Text('consent-review-page')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuth(permissions)),
        slaDashboardProvider.overrideWith((ref) async => _sla),
        coordinatorScopeProvider.overrideWith((ref) async => scope),
        coordinatorRepositoryProvider.overrideWithValue(
          repo ??
              (FakeCoordinatorRepository()
                ..results = [Right(pendingPage(items: const []))]),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  final title = 'coordinator.nav.consent_title'.tr();

  testWidgets('shows with consent:verify and sections in scope',
      (tester) async {
    await _pumpHub(
      tester,
      permissions: const ['consent:verify'],
      scope: _withSections,
    );

    expect(find.text(title), findsOneWidget);
  });

  testWidgets('hidden without consent:verify', (tester) async {
    await _pumpHub(
      tester,
      permissions: const ['club_members:approve'],
      scope: _withSections,
    );

    expect(find.text(title), findsNothing);
  });

  testWidgets('hidden with consent:verify but no sections in scope',
      (tester) async {
    await _pumpHub(
      tester,
      permissions: const ['consent:verify'],
      scope: _noSections,
    );

    expect(find.text(title), findsNothing);
  });

  testWidgets('tapping it opens the consent review route', (tester) async {
    await _pumpHub(
      tester,
      permissions: const ['consent:verify'],
      scope: _withSections,
    );

    await tester.tap(find.text(title));
    await tester.pumpAndSettle();

    expect(find.text('consent-review-page'), findsOneWidget);
  });

  group('pending forms badge', () {
    testWidgets('shows the total of the queue on the entry', (tester) async {
      final repo = FakeCoordinatorRepository()
        ..results = [
          Right(
            pendingPage(
              items: [pendingItemJson(id: 'a', sectionId: 2)],
              total: 12,
            ),
          ),
        ];
      await _pumpHub(
        tester,
        permissions: const ['consent:verify'],
        scope: _withSections,
        repo: repo,
      );

      expect(find.text('12'), findsOneWidget);
      // Cheap: a single row asked, not the whole queue.
      expect(repo.calls, [(limit: 1, offset: 0)]);
    });

    testWidgets('no badge when nothing is waiting', (tester) async {
      await _pumpHub(
        tester,
        permissions: const ['consent:verify'],
        scope: _withSections,
      );

      expect(find.text(title), findsOneWidget);
      expect(find.byType(SacBadge), findsNothing);
    });

    testWidgets('no badge (and the entry still works) when the count fails',
        (tester) async {
      final repo = FakeCoordinatorRepository()
        ..results = [const Left(permissionDeniedFailure)];
      await _pumpHub(
        tester,
        permissions: const ['consent:verify'],
        scope: _withSections,
        repo: repo,
      );

      expect(find.text(title), findsOneWidget);
      expect(find.byType(SacBadge), findsNothing);
    });

    testWidgets('re-reads the total when coming back from the queue',
        (tester) async {
      final repo = FakeCoordinatorRepository()
        ..results = [
          Right(
            pendingPage(
              items: [pendingItemJson(id: 'a', sectionId: 2)],
              total: 12,
            ),
          ),
          Right(
            pendingPage(
              items: [pendingItemJson(id: 'a', sectionId: 2)],
              total: 11,
            ),
          ),
        ];
      final router = await _pumpHub(
        tester,
        permissions: const ['consent:verify'],
        scope: _withSections,
        repo: repo,
      );
      expect(find.text('12'), findsOneWidget);

      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();

      expect(repo.calls, hasLength(2));
      expect(find.text('11'), findsOneWidget);
      expect(find.text('12'), findsNothing);
    });

    testWidgets('does not ask the server when the entry is hidden',
        (tester) async {
      final repo = FakeCoordinatorRepository()
        ..results = [Right(pendingPage(items: const [], total: 5))];
      await _pumpHub(
        tester,
        permissions: const ['club_members:approve'],
        scope: _withSections,
        repo: repo,
      );

      expect(repo.calls, isEmpty);
    });
  });
}
