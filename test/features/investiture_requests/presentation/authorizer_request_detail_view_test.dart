import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/investiture_request.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/investiture_resolution.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/views/authorizer_request_detail_view.dart';

import '../fake_investiture_requests_repository.dart';
import 'authorizer_test_support.dart';
import 'investiture_test_harness.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeInvestitureRequestsRepository repo,
) =>
    pumpApp(
      tester,
      const AuthorizerRequestDetailView(requestId: 'r1'),
      overrides: authorizerOverrides(repo),
    );

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await settle(tester);
}

Finder _invest(String personId) => find.byKey(ValueKey('invest-$personId'));
Finder _reject(String personId) => find.byKey(ValueKey('reject-$personId'));

Future<void> _tapKey(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

/// Rechaza a [personId] escribiendo [reason] en la hoja del motivo.
Future<void> _rejectWith(
  WidgetTester tester,
  String personId,
  String reason,
) async {
  await _tapKey(tester, _reject(personId));
  await tester.enterText(find.byType(TextField), reason);
  await tester.pump();
  await tester.tap(find.widgetWithText(SacButton, 'Guardar motivo'));
  await settle(tester);
}

void main() {
  setUpAll(initInvestitureTestEnv);

  FakeInvestitureRequestsRepository repoWith({
    bool secondCanAuthorize = true,
    List<RequestPerson>? extra,
    InvestitureActor? createdBy,
  }) =>
      FakeInvestitureRequestsRepository()
        ..authorizerRequest = authorizerRequest(
          createdBy: createdBy,
          people: [
            requestPerson('p1', 'Ana Pérez'),
            requestPerson('p2', 'Beto Gómez', canAuthorize: secondCanAuthorize),
            ...?extra,
          ],
        );

  group('AuthorizerRequestDetailView', () {
    testWidgets('shows the club, who sent it and the people waiting',
        (tester) async {
      await _pump(
        tester,
        repoWith(
          createdBy: const InvestitureActor(userId: 'd1', name: 'Mariana Paz'),
        ),
      );

      expect(find.text('Club Alfa'), findsOneWidget);
      expect(
          find.textContaining('Conquistadores · investidura'), findsOneWidget);
      expect(find.text('Envió Mariana Paz · 1 oct 2026'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Beto Gómez'), findsOneWidget);
      // Nada decidido todavía: el botón no ofrece confirmar.
      expect(
        tester
            .widget<SacButton>(find.widgetWithText(
                SacButton, 'Confirmar · 0 investir · 0 rechazar'))
            .isEnabled,
        isFalse,
      );
      expect(find.text('2 sin decidir quedarán en espera'), findsOneWidget);
    });

    testWidgets('has no decision controls for people it cannot authorize',
        (tester) async {
      await _pump(tester, repoWith(secondCanAuthorize: false));

      expect(_invest('p1'), findsOneWidget);
      expect(_invest('p2'), findsNothing);
      expect(_reject('p2'), findsNothing);
    });

    testWidgets('the check and cross are at least 44 dp', (tester) async {
      await _pump(tester, repoWith());

      for (final finder in [_invest('p1'), _reject('p1')]) {
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('the check invests in the same row, with no comment',
        (tester) async {
      final repo = repoWith();
      await _pump(tester, repo);

      await _tapKey(tester, _invest('p1'));
      expect(find.text('Confirmar · 1 investir · 0 rechazar'), findsOneWidget);
      expect(find.text('1 sin decidir quedarán en espera'), findsOneWidget);

      // Un segundo toque quita la decisión.
      await _tapKey(tester, _invest('p1'));
      expect(find.text('Confirmar · 0 investir · 0 rechazar'), findsOneWidget);
    });

    testWidgets('the cross asks only for a reason; cancel leaves it undecided',
        (tester) async {
      await _pump(tester, repoWith());

      await _tapKey(tester, _reject('p2'));
      expect(find.text('Rechazar a Beto Gómez'), findsOneWidget);
      expect(find.text('Motivo (solo lo ve la directiva)'), findsOneWidget);
      // No hay opción de comentario ni de investir en la hoja.
      expect(find.text('Investir'), findsNothing);
      expect(find.text('Comentario (opcional)'), findsNothing);

      var save = tester
          .widget<SacButton>(find.widgetWithText(SacButton, 'Guardar motivo'));
      expect(save.onPressed, isNull);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      save = tester
          .widget<SacButton>(find.widgetWithText(SacButton, 'Guardar motivo'));
      expect(save.onPressed, isNull);

      await tester.tap(find.widgetWithText(SacButton, 'Cancelar'));
      await settle(tester);
      expect(find.text('Confirmar · 0 investir · 1 rechazar'), findsNothing);
      expect(find.text('Rechazar · motivo agregado'), findsNothing);
    });

    testWidgets('limits the reason to 1000 characters', (tester) async {
      await _pump(tester, repoWith());
      await _tapKey(tester, _reject('p1'));
      expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 1000);
    });

    testWidgets('a saved reason marks the row and counts as a rejection',
        (tester) async {
      await _pump(tester, repoWith());

      await _rejectWith(tester, 'p2', 'Faltan evidencias');
      expect(find.text('Rechazar · motivo agregado'), findsOneWidget);
      expect(find.text('Confirmar · 0 investir · 1 rechazar'), findsOneWidget);

      // Volver a tocar la cruz reabre la hoja con el motivo escrito.
      await _tapKey(tester, _reject('p2'));
      expect(find.text('Faltan evidencias'), findsOneWidget);
    });

    testWidgets('Investir a todos keeps the rejections already chosen',
        (tester) async {
      await _pump(tester, repoWith());

      await _rejectWith(tester, 'p2', 'Faltan evidencias');
      await _tapText(tester, 'Investir a todos');

      expect(find.text('Confirmar · 1 investir · 1 rechazar'), findsOneWidget);
      expect(find.text('Todos decididos'), findsOneWidget);
    });

    testWidgets('partial confirmation sends only the decided people',
        (tester) async {
      final repo = repoWith();
      await _pump(tester, repo);

      await _tapKey(tester, _invest('p1'));
      await _tapText(tester, 'Confirmar · 1 investir · 0 rechazar');
      // Antes de confirmar hay un diálogo; todavía no se llamó al backend.
      expect(find.text('¿Confirmar decisiones?'), findsOneWidget);
      expect(find.textContaining('Se investirá a 1 y se rechazará a 0'),
          findsOneWidget);
      expect(repo.calls, isEmpty);
      await _tapText(tester, 'Confirmar');

      expect(repo.calls, ['resolve']);
      expect(repo.lastArgs!['requestId'], 'r1');
      expect(repo.lastArgs!['invest'], [const InvestDecision(personId: 'p1')]);
      expect(repo.lastArgs!['reject'], isEmpty);
    });

    testWidgets('sends invest and reject together', (tester) async {
      final repo = repoWith();
      await _pump(tester, repo);

      await _tapKey(tester, _invest('p1'));
      await _rejectWith(tester, 'p2', 'Faltan evidencias');
      await _tapText(tester, 'Confirmar · 1 investir · 1 rechazar');
      await _tapText(tester, 'Confirmar');

      expect(repo.lastArgs!['invest'], [const InvestDecision(personId: 'p1')]);
      expect(repo.lastArgs!['reject'], [
        const RejectDecision(personId: 'p2', reason: 'Faltan evidencias'),
      ]);
    });

    testWidgets('reviewing again sends nothing', (tester) async {
      final repo = repoWith();
      await _pump(tester, repo);

      await _tapKey(tester, _invest('p1'));
      await _tapText(tester, 'Confirmar · 1 investir · 0 rechazar');
      await _tapText(tester, 'Revisar otra vez');

      expect(repo.calls, isEmpty);
      expect(find.text('Confirmar · 1 investir · 0 rechazar'), findsOneWidget);
    });

    group('result', () {
      InvestitureResolution resolution() => InvestitureResolution(
            requestId: 'r1',
            invested: [
              requestPerson('p1', 'Ana Pérez', status: PersonStatus.invested),
            ],
            rejectedByPerson: [
              requestPerson('p2', 'Beto Gómez',
                  status: PersonStatus.rejectedByPerson),
            ],
            rejectedBySystem: [
              requestPerson(
                'p3',
                'Carla Ruiz',
                status: PersonStatus.rejectedBySystem,
              ),
            ],
            retired: const [],
            blocked: const [
              BlockedDecision(
                personId: 'p2',
                code: 'INVESTITURE_REQUEST_DATE_OUTSIDE_WINDOW',
              ),
            ],
            alreadyResolved: const [],
          );

      testWidgets('is a full state with the outcome in plain words',
          (tester) async {
        final repo = repoWith()..resolution = resolution();
        await _pump(tester, repo);

        await _tapKey(tester, _invest('p1'));
        await _tapText(tester, 'Confirmar · 1 investir · 0 rechazar');
        await _tapText(tester, 'Confirmar');

        expect(find.text('Decisiones confirmadas'), findsOneWidget);
        expect(find.text('1 investido'), findsOneWidget);
        expect(find.text('1 no investido'), findsOneWidget);
        expect(find.text('Rechazados por el sistema (1)'), findsOneWidget);
        expect(find.text('No se aplicaron (1)'), findsOneWidget);
        expect(
          find.textContaining(
              'La fecha de investidura queda fuera de la ventana del Campo'),
          findsOneWidget,
        );
        expect(find.text('Volver a autorizaciones'), findsOneWidget);
        // La lista de decisiones ya no está.
        expect(_invest('p1'), findsNothing);
        expect(find.textContaining('sin decidir'), findsNothing);
      });

      testWidgets('Volver a autorizaciones goes back to the list',
          (tester) async {
        final repo = repoWith()..resolution = resolution();
        final router = GoRouter(
          initialLocation: RouteNames.investitureAuthorize,
          routes: [
            GoRoute(
              path: RouteNames.investitureAuthorize,
              builder: (context, state) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => context
                        .push(RouteNames.investitureAuthorizeDetailPath('r1')),
                    child: const Text('abrir lista'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: RouteNames.investitureAuthorizeDetail,
              builder: (context, state) =>
                  const AuthorizerRequestDetailView(requestId: 'r1'),
            ),
          ],
        );
        await pumpRouterApp(tester, router,
            overrides: authorizerOverrides(repo));
        await _tapText(tester, 'abrir lista');

        await _tapKey(tester, _invest('p1'));
        await _tapText(tester, 'Confirmar · 1 investir · 0 rechazar');
        await _tapText(tester, 'Confirmar');
        await _tapText(tester, 'Volver a autorizaciones');

        expect(find.text('abrir lista'), findsOneWidget);
        expect(find.text('Decisiones confirmadas'), findsNothing);
      });
    });

    testWidgets('never shows the human rejection reason of a resolved person',
        (tester) async {
      await _pump(
        tester,
        repoWith(
          extra: [
            requestPerson(
              'p9',
              'Dani Soto',
              status: PersonStatus.rejectedByPerson,
              canAuthorize: false,
              rejectionReason: 'Motivo privado de la directiva',
            ),
          ],
        ),
      );

      expect(find.text('Dani Soto'), findsOneWidget);
      expect(find.textContaining('Motivo privado'), findsNothing);
    });

    Future<void> confirmOneDecision(WidgetTester tester) async {
      await _tapKey(tester, _invest('p1'));
      await _tapText(tester, 'Confirmar · 1 investir · 0 rechazar');
      await _tapText(tester, 'Confirmar');
    }

    testWidgets('a closed window blocks the decisions (by error code)',
        (tester) async {
      final repo = repoWith()
        ..writeFailure = const ServerFailure(
          message: 'texto que no se compara',
          code: 409,
          errorCode: 'INVESTITURE_REQUEST_WINDOW_CLOSED',
        );
      await _pump(tester, repo);
      await confirmOneDecision(tester);

      expect(
        find.text(
          'La ventana del Campo está cerrada. Por ahora no se pueden confirmar decisiones.',
        ),
        findsOneWidget,
      );
      // Los controles quedan apagados y ya no se ofrece confirmar.
      expect(tester.widget<InkWell>(_invest('p1')).onTap, isNull);
      expect(find.textContaining('Confirmar ·'), findsNothing);
    });

    testWidgets('a closed year blocks the decisions (by error code)',
        (tester) async {
      final repo = repoWith()
        ..writeFailure = const ServerFailure(
          message: 'texto que no se compara',
          code: 409,
          errorCode: 'INVESTITURE_REQUEST_YEAR_CLOSED',
        );
      await _pump(tester, repo);
      await confirmOneDecision(tester);

      expect(
        find.text(
          'El año eclesiástico está cerrado. Por ahora no se pueden confirmar decisiones.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<InkWell>(_invest('p1')).onTap, isNull);
    });

    testWidgets('the same message without the code is not treated as closed',
        (tester) async {
      final repo = repoWith()
        ..writeFailure = const ServerFailure(
          message:
              'La ventana del Campo no permite presentar ni agregar personas',
        );
      await _pump(tester, repo);
      await confirmOneDecision(tester);

      expect(
        find.text(
          'La ventana del Campo está cerrada. Por ahora no se pueden confirmar decisiones.',
        ),
        findsNothing,
      );
      // El error se avisa y las decisiones siguen disponibles.
      expect(_invest('p1'), findsOneWidget);
    });

    testWidgets('shows a retry state when loading fails', (tester) async {
      final repo = repoWith()
        ..readFailure = const ServerFailure(message: 'Falló el servidor');
      await _pump(tester, repo);
      expect(find.text('No pudimos cargar la solicitud'), findsOneWidget);

      repo.readFailure = null;
      await tester.tap(find.text('Reintentar'));
      await settle(tester);
      expect(find.text('Ana Pérez'), findsOneWidget);
    });
  });
}
