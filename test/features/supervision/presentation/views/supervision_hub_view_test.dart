/// Widget tests for the territorial supervision hub (Union / Division root).
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/onboarding_mode.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_pending_counts.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_hub_view.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_count_pill.dart';

import '../../../coordinator/coordinator_test_harness.dart';
import '../../../../support/riverpod_test_support.dart';

const _appView = 'supervision.app_view';

const _queueCaps = [
  'club_enrollments.validate',
  'folders.evaluate',
  'requests.review_territory',
  'union_camporees.approve_registrations',
];

const _territoryCaps = [
  'analytics.operations_dashboard',
  'clubs.view_territory',
  'reports.view_territory',
  'annual_progress.view_territory',
];

const _unionCaps = [_appView, ..._queueCaps, ..._territoryCaps];

const _unionTerritory = AuthorizationTerritory(level: 'union', unionId: 1);
const _divisionTerritory =
    AuthorizationTerritory(level: 'division', divisionId: 1);

const _counts = SupervisionPendingCounts(
  territoryLevel: 'union',
  clubEnrollments: 3,
  annualFolders: 2,
  unionCamporeeRegistrations: 4,
  transfers: 1,
  roleAssignments: 2,
);

const _grant = AuthorizationGrant(
  assignmentId: 'a1',
  roleName: 'counselor',
  clubId: 1,
  sectionId: 4,
  status: 'active',
);

UserEntity _user({
  String? name,
  List<String> capabilities = _unionCaps,
  AuthorizationTerritory? territory = _unionTerritory,
  List<AuthorizationGrant> clubAssignments = const [],
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      name: name,
      postRegisterComplete: true,
      onboardingMode: OnboardingMode.clubExempt,
      authorization: AuthorizationSnapshot(
        effectivePermissions: const ['clubs:read'],
        clubAssignments: clubAssignments,
        activeAssignmentId: clubAssignments.isEmpty ? null : 'a1',
        capabilities: capabilities,
        territory: territory,
      ),
    );

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.user, this.onRefresh);

  final UserEntity? user;
  final void Function() onRefresh;

  @override
  Future<UserEntity?> build() async => user;

  @override
  Future<bool> refreshAuthorization({
    Duration minInterval = const Duration(seconds: 30),
  }) async {
    onRefresh();
    return false;
  }
}

const _routes = [
  RouteNames.supervisionEnrollments,
  RouteNames.supervisionFolders,
  RouteNames.supervisionRequests,
  RouteNames.supervisionUnionCamporees,
  RouteNames.supervisionOperations,
  RouteNames.supervisionClubs,
  RouteNames.supervisionReports,
  RouteNames.supervisionAnnualProgress,
  RouteNames.notificationsInbox,
];

class _Harness {
  int countsCalls = 0;
  int authRefreshCalls = 0;
}

Future<_Harness> _pumpHub(
  WidgetTester tester, {
  UserEntity? user,
  FutureOr<SupervisionPendingCounts> Function(int call)? counts,
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  } else {
    useTallSurface(tester);
  }
  final h = _Harness();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SupervisionHubView()),
      for (final route in _routes)
        GoRoute(path: route, builder: (_, __) => Text('page:$route')),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          () => _FakeAuthNotifier(user ?? _user(), () => h.authRefreshCalls++),
        ),
        supervisionPendingCountsProvider.overrideWith((ref) async {
          h.countsCalls++;
          return (counts ?? (_) => _counts)(h.countsCalls);
        }),
      ],
      child: localized(
        (context) => MaterialApp.router(
          routerConfig: router,
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              disableAnimations: true,
              textScaler:
                  textScale == null ? null : TextScaler.linear(textScale),
            ),
            child: child!,
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return h;
}

const _enrollTitle = 'Inscripciones de club';
const _foldersTitle = 'Carpetas anuales';
const _requestsTitle = 'Traslados y asignaciones';
const _camporeeTitle = 'Camporee de unión';
const _opsTitle = 'Operación';
const _clubsTitle = 'Clubes';
const _reportsTitle = 'Informes mensuales';
const _progressTitle = 'Progreso anual';

void main() {
  setUpAll(initCoordinatorTestLocalization);

  group('rows by capability', () {
    testWidgets(
        'union director sees four queues, four territory rows and '
        'the pending phrases', (tester) async {
      await _pumpHub(tester);

      for (final title in [
        _enrollTitle,
        _foldersTitle,
        _requestsTitle,
        _camporeeTitle,
        _opsTitle,
        _clubsTitle,
        _reportsTitle,
        _progressTitle,
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('POR ATENDER'), findsOneWidget);
      expect(find.text('TU TERRITORIO'), findsOneWidget);

      expect(find.text('3 por validar'), findsOneWidget);
      expect(find.text('2 por evaluar'), findsOneWidget);
      // requests = transfers (1) + role assignments (2).
      expect(find.text('3 por revisar'), findsOneWidget);
      expect(find.text('4 por aprobar'), findsOneWidget);
      // Territory rows show their description.
      expect(find.text('Indicadores de clubes y miembros'), findsOneWidget);
    });

    testWidgets(
        'summary box shows the total, the queues that hold it and a legend '
        'per queue', (tester) async {
      await _pumpHub(tester);

      // 3 + 2 + (1 + 2) + 4
      expect(find.textContaining('12  ·  en 4 de 4 colas'), findsOneWidget);
      expect(find.text('3 DE 4'), findsNothing);
      expect(find.text('4 DE 4'), findsOneWidget);
      final bar = tester.widget<SacStatusBar>(find.byType(SacStatusBar));
      expect(
        [for (final s in bar.segments!) s.label],
        ['Inscripciones 3', 'Carpetas 2', 'Traslados 3', 'Camporee 4'],
      );
    });

    testWidgets('summary only counts the queues the actor holds',
        (tester) async {
      await _pumpHub(
        tester,
        user: _user(capabilities: const [_appView, 'folders.evaluate']),
      );

      expect(find.textContaining('2  ·  en 1 de 1 cola'), findsOneWidget);
      expect(find.textContaining('12'), findsNothing);
    });

    testWidgets('queues at zero are left out of the summary and its count',
        (tester) async {
      await _pumpHub(
        tester,
        counts: (_) => const SupervisionPendingCounts(
          territoryLevel: 'union',
          clubEnrollments: 3,
        ),
      );

      expect(find.textContaining('3  ·  en 1 de 4 colas'), findsOneWidget);
      expect(find.text('1 DE 4'), findsOneWidget);
      final bar = tester.widget<SacStatusBar>(find.byType(SacStatusBar));
      expect([for (final s in bar.segments!) s.label], ['Inscripciones 3']);
    });

    testWidgets('a queue with pending shows a count pill, one at zero does not',
        (tester) async {
      await _pumpHub(
        tester,
        counts: (_) => const SupervisionPendingCounts(
          territoryLevel: 'union',
          clubEnrollments: 3,
          annualFolders: 0,
          transfers: 0,
          roleAssignments: 0,
          unionCamporeeRegistrations: 0,
        ),
      );

      final pill = find.byType(SupervisionCountPill);
      expect(pill, findsOneWidget);
      expect(tester.widget<SupervisionCountPill>(pill).count, 3);
    });

    testWidgets('every queue at zero swaps the summary for "Todo al día"',
        (tester) async {
      await _pumpHub(
        tester,
        counts: (_) => const SupervisionPendingCounts(
          territoryLevel: 'union',
          clubEnrollments: 0,
          annualFolders: 0,
          transfers: 0,
          roleAssignments: 0,
          unionCamporeeRegistrations: 0,
        ),
      );

      expect(find.text('Todo al día'), findsOneWidget);
      expect(
        find.text(
            'No hay nada esperando tu decisión. Te avisamos cuando llegue algo.'),
        findsOneWidget,
      );
      expect(find.byType(SacStatusBar), findsNothing);
      expect(find.byType(SupervisionCountPill), findsNothing);
      expect(find.text('0 DE 4'), findsOneWidget);
      expect(find.text('Al día'), findsNWidgets(4));
    });

    testWidgets('no summary or all-clear panel while the counts are unknown',
        (tester) async {
      await _pumpHub(
        tester,
        counts: (_) => const SupervisionPendingCounts(territoryLevel: 'union'),
      );

      expect(find.text('Todo al día'), findsNothing);
      expect(find.byType(SacStatusBar), findsNothing);
    });

    testWidgets('division actor has no union camporee row', (tester) async {
      await _pumpHub(
        tester,
        user: _user(
          capabilities: const [
            _appView,
            'club_enrollments.validate',
            'folders.evaluate',
            'requests.review_territory',
            ..._territoryCaps,
          ],
          territory: _divisionTerritory,
        ),
      );

      expect(find.text(_enrollTitle), findsOneWidget);
      expect(find.text(_camporeeTitle), findsNothing);
    });

    testWidgets(
        'only camporee_orders.configure_offering does not show the camporee '
        'row (it follows the gate of the screen it opens)', (tester) async {
      await _pumpHub(
        tester,
        user: _user(
          capabilities: const [_appView, 'camporee_orders.configure_offering'],
        ),
        counts: (_) => const SupervisionPendingCounts(territoryLevel: 'union'),
      );

      expect(find.text(_camporeeTitle), findsNothing);
      expect(
          find.text('Inscripciones, pagos, pedidos e insumos'), findsNothing);
      expect(find.text('POR ATENDER'), findsNothing);
      expect(find.text('TU TERRITORIO'), findsNothing);
    });

    testWidgets(
        'union_camporees.approve_registrations shows the camporee row with '
        'its description when the count is null', (tester) async {
      await _pumpHub(
        tester,
        user: _user(
          capabilities: const [
            _appView,
            'union_camporees.approve_registrations',
          ],
        ),
        counts: (_) => const SupervisionPendingCounts(territoryLevel: 'union'),
      );

      expect(find.text(_camporeeTitle), findsOneWidget);
      expect(
          find.text('Inscripciones, pagos, pedidos e insumos'), findsOneWidget);
      expect(find.text(_enrollTitle), findsNothing);
      expect(find.text('TU TERRITORIO'), findsNothing);
    });

    testWidgets('only territory capabilities hide the queues section',
        (tester) async {
      await _pumpHub(
        tester,
        user: _user(capabilities: const [_appView, 'clubs.view_territory']),
      );

      expect(find.text('POR ATENDER'), findsNothing);
      expect(find.text(_clubsTitle), findsOneWidget);
    });

    testWidgets(
        'configured territory without any function shows the empty '
        'state', (tester) async {
      final h = await _pumpHub(
        tester,
        user: _user(capabilities: const [_appView]),
      );

      expect(find.text('Sin funciones asignadas'), findsOneWidget);
      expect(find.text('POR ATENDER'), findsNothing);
      expect(find.text('TU TERRITORIO'), findsNothing);
      expect(h.countsCalls, 0);
    });
  });

  group('second line of a queue row', () {
    testWidgets('zero count reads "up to date"', (tester) async {
      await _pumpHub(
        tester,
        counts: (_) => const SupervisionPendingCounts(
          territoryLevel: 'union',
          clubEnrollments: 0,
          annualFolders: 1,
          unionCamporeeRegistrations: 0,
          transfers: 0,
          roleAssignments: 0,
        ),
      );

      expect(find.text('Al día'), findsNWidgets(3));
      expect(find.text('1 por evaluar'), findsOneWidget);
    });

    testWidgets('null count falls back to the description', (tester) async {
      await _pumpHub(
        tester,
        counts: (_) => const SupervisionPendingCounts(territoryLevel: 'union'),
      );

      expect(
          find.text('Valida las inscripciones de los clubes'), findsOneWidget);
      expect(
          find.text('Revisa traslados y cargos entre clubes'), findsOneWidget);
      expect(find.textContaining('por validar'), findsNothing);
      expect(find.text('Al día'), findsNothing);
    });

    testWidgets('while counts load no pending or description text is shown',
        (tester) async {
      final never = Completer<SupervisionPendingCounts>();
      await _pumpHub(tester, counts: (_) => never.future, settle: false);

      expect(find.text(_enrollTitle), findsOneWidget);
      expect(find.textContaining('por validar'), findsNothing);
      expect(find.text('Valida las inscripciones de los clubes'), findsNothing);
      expect(find.text('Al día'), findsNothing);
      // No eyebrow total before the counts arrive.
      expect(find.text('0'), findsNothing);

      never.complete(_counts);
      await tester.pumpAndSettle();
      expect(find.text('3 por validar'), findsOneWidget);
    });
  });

  group('counts failure', () {
    testWidgets('shows a footnote, keeps rows tappable and retry refetches',
        (tester) async {
      final h = await _pumpHub(
        tester,
        counts: (call) =>
            call == 1 ? throw const SupervisionLoadException('boom') : _counts,
      );

      expect(
          find.text('No se pudieron cargar los pendientes.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      // Rows stay, with their description.
      expect(
          find.text('Valida las inscripciones de los clubes'), findsOneWidget);
      expect(find.text('12'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(h.countsCalls, 2);
      expect(find.text('No se pudieron cargar los pendientes.'), findsNothing);
      expect(find.text('3 por validar'), findsOneWidget);
    });

    testWidgets('rows are tappable while the counts failed', (tester) async {
      await _pumpHub(
        tester,
        counts: (_) => throw const SupervisionLoadException('boom'),
      );

      await tester.tap(find.text(_foldersTitle));
      await tester.pumpAndSettle();
      expect(
          find.text('page:${RouteNames.supervisionFolders}'), findsOneWidget);
    });

    testWidgets('a forbidden failure shows no error footnote', (tester) async {
      await _pumpHub(
        tester,
        counts: (_) => throw const SupervisionLoadException(
          'forbidden',
          isForbidden: true,
        ),
      );

      expect(find.text('No se pudieron cargar los pendientes.'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
      expect(find.text(_enrollTitle), findsOneWidget);
    });
  });

  group('unconfigured territory', () {
    UserEntity unconfigured({String? name}) => _user(
        name: name,
        territory: const AuthorizationTerritory(level: 'unconfigured'));

    testWidgets('shows only the state and never reads the counts provider',
        (tester) async {
      final h = await _pumpHub(tester, user: unconfigured());

      expect(find.text('Territorio sin configurar'), findsOneWidget);
      expect(find.text('Comprobar de nuevo'), findsOneWidget);
      expect(find.textContaining('Tu cuenta aún no tiene una unión'),
          findsOneWidget);
      expect(find.text(_enrollTitle), findsNothing);
      expect(find.text(_clubsTitle), findsNothing);
      expect(find.text('POR ATENDER'), findsNothing);
      expect(find.text('TU TERRITORIO'), findsNothing);
      expect(h.countsCalls, 0);
    });

    testWidgets('keeps the greeting, a hint and a fixed recheck footer',
        (tester) async {
      await _pumpHub(tester, user: unconfigured(name: 'Mateo Herrera'));

      expect(find.text('Mateo!'), findsOneWidget);
      expect(find.text('Supervisión'), findsOneWidget);
      expect(
          find.textContaining('Cuando esté lista verás aquí'), findsOneWidget);
      expect(find.byType(SacFrostedFooter), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SacFrostedFooter),
          matching: find.text('Comprobar de nuevo'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('recheck calls refreshAuthorization and reports no change',
        (tester) async {
      final h = await _pumpHub(tester, user: unconfigured());
      expect(
          find.text('Aún no hay cambios. Inténtalo más tarde.'), findsNothing);

      await tester.tap(find.text('Comprobar de nuevo'));
      await tester.pumpAndSettle();

      expect(h.authRefreshCalls, 1);
      expect(find.text('Aún no hay cambios. Inténtalo más tarde.'),
          findsOneWidget);
      expect(h.countsCalls, 0);
    });
  });

  group('greeting header (home without a club)', () {
    testWidgets('greets the user by first name and names the union level',
        (tester) async {
      await _pumpHub(tester, user: _user(name: 'Mateo Herrera'));

      expect(find.text('Mateo!'), findsOneWidget);
      expect(find.text('Unión'), findsOneWidget);
      expect(find.text('División'), findsNothing);
      // Section title under the greeting.
      expect(find.text('Supervisión'), findsOneWidget);
      expect(find.byType(SacTopBar), findsNothing);
    });

    testWidgets('names the territory when the server sends its name',
        (tester) async {
      await _pumpHub(
        tester,
        user: _user(
          territory: const AuthorizationTerritory(
            level: 'union',
            unionId: 1,
            name: 'Unión Mexicana del Sur',
          ),
        ),
      );
      expect(find.text('Unión Mexicana del Sur'), findsOneWidget);
      expect(find.text('Unión'), findsNothing);
    });

    testWidgets('names the division level', (tester) async {
      await _pumpHub(
        tester,
        user: _user(territory: _divisionTerritory),
      );
      expect(find.text('División'), findsOneWidget);
      expect(find.text('Unión'), findsNothing);
    });

    testWidgets(
        'bell is shown for a supervisor without a club and opens the '
        'inbox', (tester) async {
      await _pumpHub(tester);

      expect(find.byTooltip('Notificaciones'), findsOneWidget);
      await tester.tap(find.byTooltip('Notificaciones'));
      await tester.pumpAndSettle();
      expect(
          find.text('page:${RouteNames.notificationsInbox}'), findsOneWidget);
    });

    testWidgets(
        'with a club the hub is a tab: top bar with the level, no greeting '
        'and no bell', (tester) async {
      await _pumpHub(
        tester,
        user: _user(name: 'Mateo Herrera', clubAssignments: const [_grant]),
      );

      expect(find.byType(SacTopBar), findsOneWidget);
      expect(find.text('Supervisión'), findsOneWidget);
      expect(find.text('Unión'), findsOneWidget);
      expect(find.text('Mateo!'), findsNothing);
      expect(find.byTooltip('Notificaciones'), findsNothing);
      expect(find.text(_enrollTitle), findsOneWidget);
    });
  });

  group('navigation', () {
    const cases = {
      _enrollTitle: RouteNames.supervisionEnrollments,
      _foldersTitle: RouteNames.supervisionFolders,
      _requestsTitle: RouteNames.supervisionRequests,
      _camporeeTitle: RouteNames.supervisionUnionCamporees,
      _opsTitle: RouteNames.supervisionOperations,
      _clubsTitle: RouteNames.supervisionClubs,
      _reportsTitle: RouteNames.supervisionReports,
      _progressTitle: RouteNames.supervisionAnnualProgress,
    };

    for (final entry in cases.entries) {
      testWidgets('tapping "${entry.key}" pushes ${entry.value}',
          (tester) async {
        await _pumpHub(tester);

        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();

        expect(find.text('page:${entry.value}'), findsOneWidget);
      });
    }
  });

  group('app lifecycle', () {
    testWidgets('resuming the app refetches the counts', (tester) async {
      final h = await _pumpHub(
        tester,
        counts: (call) => call == 1
            ? _counts
            : const SupervisionPendingCounts(
                territoryLevel: 'union',
                clubEnrollments: 9,
              ),
      );
      expect(h.countsCalls, 1);
      expect(find.text('3 por validar'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(h.countsCalls, 2);
      expect(find.text('9 por validar'), findsOneWidget);
    });

    testWidgets('other lifecycle changes do not refetch', (tester) async {
      final h = await _pumpHub(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(h.countsCalls, 1);
    });
  });

  group('layout robustness', () {
    testWidgets('text scale 2.0 does not overflow', (tester) async {
      await _pumpHub(tester, textScale: 2.0);
      final overflow = tester.takeException();
      expect(overflow, isNull, reason: '$overflow');
      expect(find.text(_enrollTitle), findsOneWidget);
    });

    testWidgets('320 wide surface at text scale 2.0 does not overflow',
        (tester) async {
      await _pumpHub(
        tester,
        size: const Size(320, 2600),
        textScale: 2.0,
      );
      final overflow = tester.takeException();
      expect(overflow, isNull, reason: '$overflow');
      expect(find.text(_enrollTitle), findsOneWidget);
    });

    testWidgets('320 wide surface in the error state does not overflow',
        (tester) async {
      await _pumpHub(
        tester,
        size: const Size(320, 2600),
        counts: (_) => throw const SupervisionLoadException('boom'),
      );
      final overflow = tester.takeException();
      expect(overflow, isNull, reason: '$overflow');
    });

    testWidgets(
      '320 wide unconfigured state does not overflow',
      (tester) async {
        await _pumpHub(
          tester,
          size: const Size(320, 800),
          user: _user(
              territory: const AuthorizationTerritory(level: 'unconfigured')),
        );
        final overflow = tester.takeException();
        expect(overflow, isNull, reason: '$overflow');
      },
    );

    testWidgets(
      '320 wide surface in the error state at text scale 2.0 does not overflow',
      (tester) async {
        await _pumpHub(
          tester,
          size: const Size(320, 2600),
          textScale: 2.0,
          counts: (_) => throw const SupervisionLoadException('boom'),
        );
        final overflow = tester.takeException();
        expect(overflow, isNull, reason: '$overflow');
      },
    );

    testWidgets(
      '320 wide unconfigured state at text scale 2.0 does not overflow',
      (tester) async {
        await _pumpHub(
          tester,
          size: const Size(320, 800),
          textScale: 2.0,
          user: _user(
              territory: const AuthorizationTerritory(level: 'unconfigured')),
        );
        final overflow = tester.takeException();
        expect(overflow, isNull, reason: '$overflow');
      },
    );
  });

  group('accessibility', () {
    testWidgets(
        'each queue row is one button labelled with title and second '
        'line', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHub(tester);

      final expected = {
        _enrollTitle: '3 por validar',
        _foldersTitle: '2 por evaluar',
        _requestsTitle: '3 por revisar',
        _camporeeTitle: '4 por aprobar',
      };
      for (final entry in expected.entries) {
        final finder = find.bySemanticsLabel(
          RegExp('${RegExp.escape(entry.key)}.*${RegExp.escape(entry.value)}',
              dotAll: true),
        );
        expect(finder, findsOneWidget, reason: entry.key);
        final data = tester.getSemantics(finder);
        expect(data.flagsCollection.isButton, isTrue, reason: entry.key);
        expect(data.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
            reason: entry.key);
      }
      handle.dispose();
    });
  });
}
