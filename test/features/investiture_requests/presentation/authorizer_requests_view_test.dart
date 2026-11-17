import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/views/authorizer_requests_view.dart';

import '../fake_investiture_requests_repository.dart';
import 'authorizer_test_support.dart';
import 'investiture_test_harness.dart';

GoRouter _router(List<String> visited) => GoRouter(
      initialLocation: RouteNames.investitureAuthorize,
      routes: [
        GoRoute(
          path: RouteNames.investitureAuthorize,
          builder: (context, state) => const AuthorizerRequestsView(),
        ),
        GoRoute(
          path: RouteNames.investitureAuthorizeDetail,
          builder: (context, state) {
            visited.add(state.matchedLocation);
            return Scaffold(body: Text('detail ${state.matchedLocation}'));
          },
        ),
      ],
    );

void main() {
  setUpAll(initInvestitureTestEnv);

  group('AuthorizerRequestsView', () {
    testWidgets('lists each request with club, section, date and pending',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..authorizerRequests = [
          authorizerRequest(
            id: 'r1',
            club: 'Club Alfa',
            section: 'Conquistadores',
            district: 'Norte',
            earliest: DateTime(2026, 11, 15),
          ),
        ];
      await pumpRouterApp(
        tester,
        _router([]),
        overrides: authorizerOverrides(repo),
      );

      expect(find.text('Autorizaciones'), findsOneWidget);
      expect(find.text('Distrito Norte · 2025-2026'), findsOneWidget);
      expect(find.text('PARA AUTORIZAR'), findsOneWidget);
      expect(find.text('Club Alfa'), findsOneWidget);
      expect(find.textContaining('Conquistadores'), findsOneWidget);
      expect(find.text('2 en espera'), findsOneWidget);
      // Pide también las resueltas.
      expect(repo.lastIncludeResolved, isTrue);
    });

    testWidgets('summary adds up the people waiting and the nearest date',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..authorizerRequests = [
          authorizerRequest(
            id: 'r1',
            club: 'Club Alfa',
            earliest: DateTime(2026, 12, 21),
          ),
          authorizerRequest(
            id: 'r2',
            club: 'Club Beta',
            clubId: 2,
            people: [
              requestPerson('x1', 'Uno'),
              requestPerson('x2', 'Dos'),
              requestPerson('x3', 'Tres'),
            ],
            earliest: DateTime(2026, 12, 14),
          ),
        ];
      await pumpRouterApp(
        tester,
        _router([]),
        overrides: authorizerOverrides(repo),
      );

      final summary = tester.widget<Text>(
        find.byKey(const ValueKey('authorizer-summary-people')),
      );
      expect(summary.textSpan!.toPlainText(), '5  ·  en 2 clubes');
      expect(find.textContaining('La más próxima:'), findsOneWidget);
      expect(find.textContaining('14 dic · Club Beta'), findsOneWidget);
    });

    testWidgets('resolved requests go last with their result', (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..authorizerRequests = [
          authorizerRequest(
            id: 'done',
            club: 'Club Sirio',
            people: [requestPerson('x', 'Ya', status: PersonStatus.invested)],
            investedCount: 6,
          ),
          authorizerRequest(id: 'open', club: 'Club Abierto'),
        ];
      await pumpRouterApp(
        tester,
        _router([]),
        overrides: authorizerOverrides(repo),
      );

      expect(find.text('RESUELTAS'), findsOneWidget);
      expect(find.text('6 investidos'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Club Abierto')).dy,
        lessThan(tester.getTopLeft(find.text('Club Sirio')).dy),
      );
    });

    testWidgets('opens the request detail when a card is tapped',
        (tester) async {
      final visited = <String>[];
      final repo = FakeInvestitureRequestsRepository()
        ..authorizerRequests = [authorizerRequest(id: 'r-77')];
      await pumpRouterApp(
        tester,
        _router(visited),
        overrides: authorizerOverrides(repo),
      );

      await tester.tap(find.text('Club Alfa'));
      await settle(tester);

      expect(visited, ['/investiture/authorize/r-77']);
    });

    testWidgets('shows an empty state without requests', (tester) async {
      await pumpRouterApp(
        tester,
        _router([]),
        overrides: authorizerOverrides(FakeInvestitureRequestsRepository()),
      );
      expect(find.text('No hay solicitudes por autorizar'), findsOneWidget);
    });

    testWidgets('shows a retry state when loading fails', (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..readFailure = const ServerFailure(message: 'Falló el servidor');
      await pumpRouterApp(
        tester,
        _router([]),
        overrides: authorizerOverrides(repo),
      );
      expect(find.text('No pudimos cargar las autorizaciones'), findsOneWidget);

      repo
        ..readFailure = null
        ..authorizerRequests = [authorizerRequest()];
      await tester.tap(find.text('Reintentar'));
      await settle(tester);
      expect(find.text('Club Alfa'), findsOneWidget);
    });

    testWidgets('a pastor without districts sees an empty state, not an error',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..readFailure = const AuthFailure(
          message: 'No tiene permiso para esta solicitud de investidura',
          code: 403,
          errorCode: 'INVESTITURE_REQUEST_FORBIDDEN',
        );
      await pumpRouterApp(
        tester,
        _router([]),
        overrides: authorizerOverrides(repo),
      );

      expect(find.text('Aún no tienes distritos asignados'), findsOneWidget);
      expect(
          find.textContaining('El Campo local debe asignarte'), findsOneWidget);
      expect(find.text('No pudimos cargar las autorizaciones'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('other failures keep the generic retry state', (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..readFailure = const AuthFailure(
          message: 'Sesión vencida',
          code: 401,
          errorCode: 'AUTH_EXPIRED',
        );
      await pumpRouterApp(
        tester,
        _router([]),
        overrides: authorizerOverrides(repo),
      );

      expect(find.text('No pudimos cargar las autorizaciones'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('director-lf and assistant-lf can open it too', (tester) async {
      for (final role in ['director-lf', 'assistant-lf']) {
        final repo = FakeInvestitureRequestsRepository()
          ..authorizerRequests = [authorizerRequest()];
        await pumpRouterApp(
          tester,
          _router([]),
          overrides: authorizerOverrides(repo, role: role),
        );
        expect(find.text('Club Alfa'), findsOneWidget, reason: role);
      }
    });

    testWidgets('is restricted to the authorizer roles', (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..authorizerRequests = [authorizerRequest()];
      await pumpRouterApp(
        tester,
        _router([]),
        overrides: authorizerOverrides(repo, role: 'coordinator'),
      );
      expect(find.text('Acceso restringido'), findsOneWidget);
      expect(find.text('Club Alfa'), findsNothing);
      expect(repo.authorizerListCalls, 0);
    });
  });
}
