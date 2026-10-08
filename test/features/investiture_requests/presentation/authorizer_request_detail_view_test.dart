import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Abre la hoja de decisión de la persona [name] (toda la fila es tocable).
Future<void> _openSheetFor(WidgetTester tester, String name) async {
  final label = find.text(name);
  await tester.ensureVisible(label.first);
  await tester.pump();
  await tester.tap(label.first);
  await settle(tester);
}

Finder _confirmButton() => find.widgetWithText(SacButton, 'Guardar decisión');

void main() {
  setUpAll(initInvestitureTestEnv);

  FakeInvestitureRequestsRepository repoWith({
    bool secondCanAuthorize = true,
    List<RequestPerson>? extra,
  }) =>
      FakeInvestitureRequestsRepository()
        ..authorizerRequest = authorizerRequest(
          people: [
            requestPerson('p1', 'Ana Pérez'),
            requestPerson('p2', 'Beto Gómez', canAuthorize: secondCanAuthorize),
            ...?extra,
          ],
        );

  group('AuthorizerRequestDetailView', () {
    testWidgets('shows the header and the people waiting', (tester) async {
      await _pump(tester, repoWith());

      expect(find.text('Club Alfa'), findsOneWidget);
      expect(find.textContaining('Distrito Norte'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Beto Gómez'), findsOneWidget);
      expect(find.text('Confirmar decisiones (0)'), findsNothing);
    });

    testWidgets('has no decision controls for people it cannot authorize',
        (tester) async {
      await _pump(tester, repoWith(secondCanAuthorize: false));

      // Solo la primera persona ofrece decidir.
      expect(find.text('Decidir'), findsOneWidget);
    });

    testWidgets('sends the invest and reject decisions after confirming',
        (tester) async {
      final repo = repoWith();
      await _pump(tester, repo);

      // Ana: investir con un comentario.
      await _openSheetFor(tester, 'Ana Pérez');
      await _tapText(tester, 'Investir');
      await tester.enterText(find.byType(TextField), 'Gracias por el camino');
      await tester.pump();
      await tester.tap(_confirmButton());
      await settle(tester);

      // Beto: rechazar con motivo.
      await _openSheetFor(tester, 'Beto Gómez');
      await _tapText(tester, 'Rechazar');
      await tester.enterText(find.byType(TextField), 'Faltan evidencias');
      await tester.pump();
      await tester.tap(_confirmButton());
      await settle(tester);

      expect(find.text('Confirmar decisiones (2)'), findsOneWidget);
      await _tapText(tester, 'Confirmar decisiones (2)');
      // Antes de confirmar hay un diálogo; todavía no se llamó al backend.
      expect(repo.calls, isEmpty);
      await _tapText(tester, 'Confirmar');

      expect(repo.calls, ['resolve']);
      expect(repo.lastArgs!['requestId'], 'r1');
      expect(repo.lastArgs!['invest'], [
        const InvestDecision(personId: 'p1', comment: 'Gracias por el camino'),
      ]);
      expect(repo.lastArgs!['reject'], [
        const RejectDecision(personId: 'p2', reason: 'Faltan evidencias'),
      ]);
    });

    testWidgets('cancelling the confirmation sends nothing', (tester) async {
      final repo = repoWith();
      await _pump(tester, repo);

      await _openSheetFor(tester, 'Ana Pérez');
      await _tapText(tester, 'Investir');
      await tester.tap(_confirmButton());
      await settle(tester);

      await _tapText(tester, 'Confirmar decisiones (1)');
      await _tapText(tester, 'Cancelar');

      expect(repo.calls, isEmpty);
      expect(find.text('Confirmar decisiones (1)'), findsOneWidget);
    });

    testWidgets('an invest decision without a comment omits it',
        (tester) async {
      final repo = repoWith();
      await _pump(tester, repo);

      await _openSheetFor(tester, 'Ana Pérez');
      await _tapText(tester, 'Investir');
      await tester.tap(_confirmButton());
      await settle(tester);
      await _tapText(tester, 'Confirmar decisiones (1)');
      await _tapText(tester, 'Confirmar');

      expect(repo.lastArgs!['invest'], [
        const InvestDecision(personId: 'p1'),
      ]);
      expect(repo.lastArgs!['reject'], isEmpty);
    });

    testWidgets('a rejection without a reason cannot be saved', (tester) async {
      await _pump(tester, repoWith());

      await _openSheetFor(tester, 'Ana Pérez');
      await _tapText(tester, 'Rechazar');

      var button = tester.widget<SacButton>(_confirmButton());
      expect(button.onPressed, isNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      button = tester.widget<SacButton>(_confirmButton());
      expect(button.onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Faltan evidencias');
      await tester.pump();
      button = tester.widget<SacButton>(_confirmButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('limits the comment to 500 and the reason to 1000',
        (tester) async {
      await _pump(tester, repoWith());

      await _openSheetFor(tester, 'Ana Pérez');
      await _tapText(tester, 'Investir');
      expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 500);

      await _tapText(tester, 'Rechazar');
      expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 1000);
    });

    testWidgets('a decision can be changed or cleared before confirming',
        (tester) async {
      final repo = repoWith();
      await _pump(tester, repo);

      await _openSheetFor(tester, 'Ana Pérez');
      await _tapText(tester, 'Investir');
      await tester.tap(_confirmButton());
      await settle(tester);
      expect(find.text('Confirmar decisiones (1)'), findsOneWidget);

      await _openSheetFor(tester, 'Ana Pérez');
      await _tapText(tester, 'Quitar decisión');
      expect(find.text('Confirmar decisiones (1)'), findsNothing);
      expect(repo.calls, isEmpty);
    });

    testWidgets('shows the outcome summary after resolving', (tester) async {
      final repo = repoWith()
        ..resolution = InvestitureResolution(
          requestId: 'r1',
          invested: [
            requestPerson('p1', 'Ana Pérez', status: PersonStatus.invested)
          ],
          rejectedByPerson: const [],
          rejectedBySystem: [
            requestPerson(
              'p3',
              'Carla Ruiz',
              status: PersonStatus.rejectedBySystem,
              systemReason: 'Al comprobar el avance, no cubría el requisito 4.',
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
      await _pump(tester, repo);

      await _openSheetFor(tester, 'Ana Pérez');
      await _tapText(tester, 'Investir');
      await tester.tap(_confirmButton());
      await settle(tester);
      await _tapText(tester, 'Confirmar decisiones (1)');
      await _tapText(tester, 'Confirmar');

      expect(find.text('Resultado de las decisiones'), findsOneWidget);
      expect(find.text('Investidos (1)'), findsOneWidget);
      expect(find.text('Rechazados por el sistema (1)'), findsOneWidget);
      expect(
        find.text('Al comprobar el avance, no cubría el requisito 4.'),
        findsOneWidget,
      );
      expect(find.text('No se aplicaron (1)'), findsOneWidget);
      expect(
        find.text(
            'La fecha de investidura queda fuera de la ventana del Campo'),
        findsOneWidget,
      );
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

    testWidgets('a closed window or year blocks the decisions', (tester) async {
      final repo = repoWith()
        ..writeFailure = const ServerFailure(
          message:
              'La ventana del Campo no permite presentar ni agregar personas',
        );
      await _pump(tester, repo);

      await _openSheetFor(tester, 'Ana Pérez');
      await _tapText(tester, 'Investir');
      await tester.tap(_confirmButton());
      await settle(tester);
      await _tapText(tester, 'Confirmar decisiones (1)');
      await _tapText(tester, 'Confirmar');

      expect(
        find.text(
          'La ventana del Campo está cerrada. Por ahora no se pueden confirmar decisiones.',
        ),
        findsOneWidget,
      );
      expect(find.text('Decidir'), findsNothing);
      expect(find.text('Confirmar decisiones (1)'), findsNothing);
    });

    testWidgets('shows a retry state when loading fails', (tester) async {
      final repo = repoWith()
        ..readFailure = const ServerFailure(message: 'sin conexión');
      await _pump(tester, repo);
      expect(find.text('No pudimos cargar la solicitud'), findsOneWidget);

      repo.readFailure = null;
      await tester.tap(find.text('Reintentar'));
      await settle(tester);
      expect(find.text('Ana Pérez'), findsOneWidget);
    });
  });
}
