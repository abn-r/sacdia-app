/// Tests for CoordinatorClubsListView ("Mis clubes").
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_club.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_scope.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/coordinator_clubs_list_view.dart';

import '../../coordinator_test_harness.dart';

const _clubs = [
  CoordinatorClub(
    id: 1,
    name: 'Club Conquistadores Norte',
    localFieldId: 10,
    districtName: 'Distrito Norte',
    localFieldName: 'Campo Local 1',
    sections: [
      CoordinatorSectionScope(
        clubSectionId: 7,
        clubTypeId: 2,
        name: 'Conquistadores',
      ),
      CoordinatorSectionScope(
        clubSectionId: 8,
        clubTypeId: 1,
        name: 'Aventureros',
      ),
    ],
  ),
  CoordinatorClub(id: 2, name: 'Club Aventureros Sur', localFieldId: 10),
  CoordinatorClub(id: 3, name: 'Club Guías Este', localFieldId: 11),
];

Future<void> _pumpView(
  WidgetTester tester,
  FutureOr<List<CoordinatorClub>> Function() load,
) async {
  useTallSurface(tester);

  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, __) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/clubs'),
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(
        path: '/clubs',
        builder: (_, __) => const CoordinatorClubsListView(),
      ),
      GoRoute(
        path: '/club/:clubId',
        builder: (_, state) =>
            Text('page:club:${state.pathParameters['clubId']}'),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coordinatorClubsRawProvider.overrideWith((ref) async => load()),
      ],
      child: localized((context) => localizedRouterApp(context, router)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initCoordinatorTestLocalization);

  group('route wiring', () {
    test('coordinatorClubs route is /coordinator/clubs', () {
      expect(RouteNames.coordinatorClubs, '/coordinator/clubs');
    });
  });

  group('data', () {
    testWidgets('frosted top bar with title and club count', (tester) async {
      await _pumpView(tester, () => _clubs);

      final bar = tester.widget<SacTopBar>(find.byType(SacTopBar));
      expect(bar.frosted, isTrue);
      expect(bar.title, 'Mis clubes');
      expect(bar.subtitle, '3 clubes');
      // Pull to refresh replaces the refresh icon and the spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows a card per club', (tester) async {
      await _pumpView(tester, () => _clubs);

      expect(find.text('Club Conquistadores Norte'), findsOneWidget);
      expect(find.text('Club Aventureros Sur'), findsOneWidget);
      expect(find.text('Club Guías Este'), findsOneWidget);
    });

    testWidgets('a card shows district · local field and section badges',
        (tester) async {
      await _pumpView(tester, () => _clubs);

      expect(find.text('Distrito Norte · Campo Local 1'), findsOneWidget);
      expect(find.widgetWithText(SacBadge, 'Conquistadores'), findsOneWidget);
      expect(find.widgetWithText(SacBadge, 'Aventureros'), findsOneWidget);
      // The old "N secciones: ..." sentence is gone.
      expect(find.textContaining('secciones'), findsNothing);
    });

    testWidgets('falls back to the local field id when it has no name',
        (tester) async {
      await _pumpView(tester, () => _clubs);

      expect(find.text('Campo local #10'), findsOneWidget);
    });

    testWidgets(
        'a card does not open the club detail (members only: the router and '
        'the API reject it for a coordinator)', (tester) async {
      await _pumpView(tester, () => _clubs);

      await tester.tap(find.text('Club Aventureros Sur'));
      await tester.pumpAndSettle();

      expect(find.text('page:club:2'), findsNothing);
      expect(find.text('Club Aventureros Sur'), findsOneWidget);
    });

    testWidgets('the back button leaves the list', (tester) async {
      await _pumpView(tester, () => _clubs);

      await tester.tap(find.byType(SacBackButton));
      await tester.pumpAndSettle();

      expect(find.byType(CoordinatorClubsListView), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('filters clubs by name', (tester) async {
      await _pumpView(tester, () => _clubs);

      expect(find.byType(SacTextField), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'aventureros');
      await tester.pumpAndSettle();

      expect(find.text('Club Aventureros Sur'), findsOneWidget);
      expect(find.text('Club Conquistadores Norte'), findsNothing);
      expect(find.text('Club Guías Este'), findsNothing);
    });

    testWidgets('no matches shows a dedicated empty state with the query',
        (tester) async {
      await _pumpView(tester, () => _clubs);

      await tester.enterText(find.byType(TextFormField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.byType(SacEmptyState), findsOneWidget);
      expect(find.text('Sin resultados'), findsOneWidget);
      expect(
        find.text('No encontramos clubes con «zzz». Prueba con otro nombre.'),
        findsOneWidget,
      );
      // The search field stays so the query can be corrected.
      expect(find.byType(SacTextField), findsOneWidget);
    });

    testWidgets('the clear button restores the full list', (tester) async {
      await _pumpView(tester, () => _clubs);

      await tester.enterText(find.byType(TextFormField), 'zzz');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Limpiar'));
      await tester.pumpAndSettle();

      expect(find.text('Club Conquistadores Norte'), findsOneWidget);
      expect(find.byType(SacEmptyState), findsNothing);
    });
  });

  group('states', () {
    testWidgets('loading shows six card skeletons and no data', (tester) async {
      final never = Completer<List<CoordinatorClub>>();
      useTallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coordinatorClubsRawProvider.overrideWith((ref) => never.future),
          ],
          child: localized(
            (context) =>
                localizedApp(context, const CoordinatorClubsListView()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(SacCard), findsNWidgets(6));
      expect(find.byType(SacErrorState), findsNothing);
      expect(find.byType(SacEmptyState), findsNothing);
      expect(find.text('Club Conquistadores Norte'), findsNothing);

      never.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('no assigned clubs shows the empty state without search',
        (tester) async {
      await _pumpView(tester, () => const []);

      expect(find.byType(SacEmptyState), findsOneWidget);
      expect(find.text('No hay clubes asignados'), findsOneWidget);
      expect(find.byType(SacTextField), findsNothing);
    });

    testWidgets('a load failure is localized, retryable and never raw',
        (tester) async {
      var calls = 0;
      await _pumpView(tester, () {
        calls++;
        throw Exception('Configuración RBAC incorrecta en el handler');
      });

      expect(find.byType(SacErrorState), findsOneWidget);
      expect(find.text('No pudimos cargar tus clubes'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('RBAC'), findsNothing);

      final before = calls;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(calls, greaterThan(before));
    });

    testWidgets('a 403 shows access restricted without retry', (tester) async {
      await _pumpView(
        tester,
        () => throw const CoordinatorLoadException(
          'No tienes permiso',
          isForbidden: true,
        ),
      );

      expect(find.text('Acceso restringido'), findsOneWidget);
      final icon = tester.widget<HugeIcon>(
        find.descendant(
          of: find.byType(SacErrorState),
          matching: find.byType(HugeIcon),
        ),
      );
      expect(icon.icon, HugeIcons.strokeRoundedLockKey);
      expect(find.text('Reintentar'), findsNothing);
    });
  });
}
