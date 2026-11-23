import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/service_credentials/domain/entities/service_credential.dart';
import 'package:sacdia_app/features/service_credentials/presentation/views/my_service_credentials_view.dart';
import 'package:sacdia_app/features/service_credentials/presentation/widgets/service_credentials_skeleton.dart';

import '../service_credentials_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeServiceCredentialsRepository repo;
  setUp(() => repo = FakeServiceCredentialsRepository());

  Future<void> open(WidgetTester tester, {bool settle = true}) =>
      pumpCredentialsApp(
        tester,
        home: const MyServiceCredentialsView(),
        overrides: credentialOverrides(repo),
        settle: settle,
      );

  Finder confirmButton() =>
      find.byKey(const ValueKey('credential-sheet-confirm'));

  testWidgets('shows a skeleton while loading', (tester) async {
    repo.mineGate = Completer<void>();
    await open(tester, settle: false);
    expect(find.byType(ServiceCredentialsSkeleton), findsOneWidget);
    repo.mineGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ServiceCredentialsSkeleton), findsNothing);
  });

  testWidgets('empty: explains the requirement and offers to upload',
      (tester) async {
    await open(tester);
    expect(find.byType(SacEmptyState), findsOneWidget);
    expect(find.text('Aún no subes ninguna constancia'), findsOneWidget);

    await tester.tap(find.text('Subir constancia'));
    await tester.pumpAndSettle();
    expect(find.text('route:/service-credentials/new'), findsOneWidget);
  });

  testWidgets('error state offers retry and recovers', (tester) async {
    repo.mine = const Left(
      ServerFailure(message: 'boom', code: 500),
    );
    await open(tester);
    expect(find.byType(SacErrorState), findsOneWidget);
    expect(find.text('No pudimos cargar tus constancias'), findsOneWidget);

    repo.mine = Right([credential()]);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byType(SacErrorState), findsNothing);
    expect(find.byType(SacStatePanel), findsOneWidget);
  });

  testWidgets('approved: panel with the course and no expiry, upload another',
      (tester) async {
    repo.mine = Right([credential(status: ServiceCredentialStatus.approved)]);
    await open(tester);

    expect(
        find.byKey(const ValueKey('credential-state-panel')), findsOneWidget);
    expect(find.text('Constancia aprobada'), findsOneWidget);
    expect(
      find.text(
          'Curso de consejería (10 horas), concluida el 14 mar 2026. No vence.'),
      findsOneWidget,
    );
    // The own entity has no file URL: the document row is not interactive.
    expect(
        find.byKey(const ValueKey('credential-document-row')), findsOneWidget);
    expect(find.text('constancia.pdf'), findsOneWidget);
    expect(find.text('Concluida el 14 mar 2026'), findsOneWidget);
    // No footer, no withdraw.
    expect(find.byType(SacFrostedFooter), findsNothing);
    expect(find.text('Retirar constancia'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('credential-upload-another')));
    await tester.pumpAndSettle();
    expect(find.text('route:/service-credentials/new'), findsOneWidget);
  });

  testWidgets('approved with expiry says until when', (tester) async {
    repo.mine = Right([
      credential(
        status: ServiceCredentialStatus.approved,
        expiresAt: DateTime(2027, 5, 20),
      ),
    ]);
    await open(tester);
    expect(
      find.text('Curso de consejería (10 horas), concluida el 14 mar 2026. '
          'Vigente hasta 20 may 2027.'),
      findsOneWidget,
    );
  });

  testWidgets('rejected: reason in its own group and resubmit in the footer',
      (tester) async {
    repo.mine = Right([
      credential(
        status: ServiceCredentialStatus.rejected,
        reason: 'Documento ilegible',
      ),
    ]);
    await open(tester);

    expect(find.text('Constancia rechazada'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('credential-reason')),
        matching: find.text('Documento ilegible'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SacFrostedFooter),
        matching: find.widgetWithText(SacButton, 'Subir de nuevo'),
      ),
      findsOneWidget,
    );
    expect(find.text('Retirar constancia'), findsNothing);

    await tester.tap(find.text('Subir de nuevo'));
    await tester.pumpAndSettle();
    expect(find.text('route:/service-credentials/new'), findsOneWidget);
  });

  testWidgets('rejected without reason shows no reason group', (tester) async {
    repo.mine = Right([credential(status: ServiceCredentialStatus.rejected)]);
    await open(tester);
    expect(find.byKey(const ValueKey('credential-reason')), findsNothing);
  });

  testWidgets('pending: panel, no upload offered and a red withdraw row',
      (tester) async {
    repo.mine = Right([credential()]);
    await open(tester);

    expect(find.text('En revisión'), findsOneWidget);
    expect(
      find.text('La enviaste el 1 abr 2026. Te avisaremos cuando la revisen.'),
      findsOneWidget,
    );
    expect(find.text('Subir constancia'), findsNothing);
    expect(find.text('Subir otra constancia'), findsNothing);
    expect(find.byType(SacFrostedFooter), findsNothing);
    expect(find.text('Retirar constancia'), findsOneWidget);
  });

  testWidgets('older credentials go to Historial with status and date',
      (tester) async {
    repo.mine = Right([
      credential(
        id: 'new',
        status: ServiceCredentialStatus.approved,
        createdAt: DateTime(2026, 6, 1),
      ),
      credential(
        id: 'old',
        status: ServiceCredentialStatus.rejected,
        createdAt: DateTime(2026, 3, 1),
      ),
    ]);
    await open(tester);

    expect(find.byKey(const ValueKey('credential-history')), findsOneWidget);
    expect(find.text('HISTORIAL'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('service-credential-old')),
        matching: find.text('Rechazada · 1 mar 2026'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('service-credential-new')), findsNothing);
  });

  testWidgets('a single credential has no Historial', (tester) async {
    repo.mine = Right([credential()]);
    await open(tester);
    expect(find.byKey(const ValueKey('credential-history')), findsNothing);
  });

  testWidgets('the empty state has no footer (it owns its action)',
      (tester) async {
    await open(tester);
    expect(find.byType(SacFrostedFooter), findsNothing);
  });

  testWidgets('the document row never shows the raw picker file name',
      (tester) async {
    repo.mine = Right([
      credential(
        status: ServiceCredentialStatus.approved,
        fileName: 'image_picker_EF659504-6A1B-4C2D-9E3F.jpg',
      ),
    ]);
    await open(tester);
    expect(find.textContaining('image_picker_'), findsNothing);
    expect(find.text('Foto'), findsOneWidget);
  });

  testWidgets('withdraw asks in a sheet first, then removes and refreshes',
      (tester) async {
    repo.mine = Right([credential(id: 'p')]);
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('credential-withdraw')));
    await tester.pumpAndSettle();
    expect(find.text('¿Retirar esta constancia?'), findsOneWidget);

    // Cancelling does nothing.
    await tester.tap(find.byKey(const ValueKey('credential-sheet-cancel')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('withdraw')), isEmpty);

    repo.mine = const Right([]);
    await tester.tap(find.byKey(const ValueKey('credential-withdraw')));
    await tester.pumpAndSettle();
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(repo.calls, contains('withdraw:p'));
    expect(find.text('Constancia retirada.'), findsOneWidget);
    // The list reloaded: now empty.
    expect(find.text('Aún no subes ninguna constancia'), findsOneWidget);
  });

  testWidgets('a failed withdraw shows the translated reason', (tester) async {
    repo.mine = Right([credential(id: 'p')]);
    repo.withdrawResult = const Left(ServerFailure(
      message: 'x',
      code: 404,
      errorCode: 'SERVICE_CREDENTIAL_NOT_FOUND',
    ));
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('credential-withdraw')));
    await tester.pumpAndSettle();
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();
    expect(find.text('No encontramos esta constancia. Actualizamos la lista.'),
        findsOneWidget);
  });
}
