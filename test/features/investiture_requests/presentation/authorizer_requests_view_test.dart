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
    testWidgets('lists each request with club, section, district and pending',
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
      expect(find.text('Club Alfa'), findsOneWidget);
      expect(find.textContaining('Conquistadores'), findsOneWidget);
      expect(find.textContaining('Distrito Norte'), findsOneWidget);
      expect(find.text('2 en espera'), findsOneWidget);
      expect(find.textContaining('15 nov 2026'), findsOneWidget);
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

    testWidgets('puts the requests with people waiting first', (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..authorizerRequests = [
          authorizerRequest(
            id: 'done',
            club: 'Club Cerrado',
            people: [requestPerson('x', 'Ya', status: PersonStatus.invested)],
          ),
          authorizerRequest(id: 'open', club: 'Club Abierto'),
        ];
      await pumpRouterApp(
        tester,
        _router([]),
        overrides: authorizerOverrides(repo),
      );

      expect(
        tester.getTopLeft(find.text('Club Abierto')).dy,
        lessThan(tester.getTopLeft(find.text('Club Cerrado')).dy),
      );
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
        ..readFailure = const ServerFailure(message: 'sin conexión');
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

      expect(
          find.text('Todavía no tenés distritos asignados.'), findsOneWidget);
      expect(find.text('Pedí al Campo que te asigne.'), findsOneWidget);
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
