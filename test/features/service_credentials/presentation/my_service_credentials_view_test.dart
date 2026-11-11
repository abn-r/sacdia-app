import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_notice.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
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

  /// The confirm button of the withdraw dialog (not the row button).
  Finder dialogWithdraw() => find.descendant(
      of: find.byType(SacDialog), matching: find.text('Retirar'));

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
    expect(find.text('Curso de consejería (10 horas)'), findsOneWidget);
  });

  testWidgets('groups by status with reason and expiry', (tester) async {
    repo.mine = Right([
      credential(
        id: 'p',
        status: ServiceCredentialStatus.pendingReview,
      ),
      credential(
        id: 'r',
        status: ServiceCredentialStatus.rejected,
        reason: 'Documento ilegible',
        createdAt: DateTime(2026, 3, 1),
      ),
      credential(
        id: 'a',
        status: ServiceCredentialStatus.approved,
        expiresAt: DateTime(2027, 5, 20),
        createdAt: DateTime(2026, 2, 1),
      ),
    ]);
    await open(tester);

    expect(find.text('En revisión · 1'), findsOneWidget);
    expect(find.text('Rechazadas · 1'), findsOneWidget);
    expect(find.text('Aprobadas · 1'), findsOneWidget);
    expect(find.text('Curso de consejería (10 horas)'), findsNWidgets(3));
    expect(find.text('Motivo: Documento ilegible'), findsOneWidget);
    expect(find.textContaining('Vigente hasta'), findsOneWidget);
    // Status pills (text, not color alone).
    expect(find.text('Aprobada'), findsOneWidget);
    expect(find.text('Rechazada'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
  });

  testWidgets('a pending credential hides the upload button', (tester) async {
    repo.mine = Right([credential()]);
    await open(tester);
    expect(find.text('Subir constancia'), findsNothing);
    expect(find.textContaining('Tienes una constancia en revisión'),
        findsOneWidget);
    // The info notice replaces the pinned upload bar.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pending-notice')),
        matching: find.byType(SacNotice),
      ),
      findsNothing, // the key sits on the notice itself
    );
    expect(find.byKey(const ValueKey('pending-notice')), findsOneWidget);
    expect(find.byType(SacPinnedActionBar), findsNothing);
  });

  testWidgets('with no pending credential the upload button is offered',
      (tester) async {
    repo.mine = Right([
      credential(status: ServiceCredentialStatus.approved),
    ]);
    await open(tester);
    expect(
      find.descendant(
        of: find.byType(SacPinnedActionBar),
        matching: find.text('Subir constancia'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pending-notice')), findsNothing);
    await tester.tap(find.text('Subir constancia'));
    await tester.pumpAndSettle();
    expect(find.text('route:/service-credentials/new'), findsOneWidget);
  });

  testWidgets('the empty state has no pinned bar (it owns its action)',
      (tester) async {
    await open(tester);
    expect(find.byType(SacPinnedActionBar), findsNothing);
  });

  testWidgets('a row never shows the raw picker file name', (tester) async {
    repo.mine = Right([
      credential(
        id: 'a',
        status: ServiceCredentialStatus.approved,
        fileName: 'image_picker_EF659504-6A1B-4C2D-9E3F.jpg',
      ),
      credential(
        id: 'b',
        status: ServiceCredentialStatus.approved,
        fileName: 'scaled_image_picker_AAAA1111-0000.png',
      ),
    ]);
    await open(tester);
    expect(find.textContaining('image_picker_'), findsNothing);
    expect(find.textContaining('Concluida el'), findsNWidgets(2));
    expect(find.textContaining('· Foto'), findsNWidgets(2));
  });

  testWidgets('a human file name is kept in the row subtitle', (tester) async {
    repo.mine = Right([credential(fileName: 'curso-2026.pdf')]);
    await open(tester);
    expect(find.textContaining('curso-2026.pdf'), findsOneWidget);
  });

  testWidgets('the rejection reason is an error notice inside the row',
      (tester) async {
    repo.mine = Right([
      credential(status: ServiceCredentialStatus.rejected, reason: 'Borroso'),
    ]);
    await open(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rejected-reason')),
        matching: find.text('Motivo: Borroso'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an approved credential cannot be withdrawn', (tester) async {
    repo.mine = Right([credential(status: ServiceCredentialStatus.approved)]);
    await open(tester);
    expect(find.text('Retirar'), findsNothing);
  });

  testWidgets('a rejected credential can be resubmitted', (tester) async {
    repo.mine = Right([
      credential(status: ServiceCredentialStatus.rejected, reason: 'Borroso'),
    ]);
    await open(tester);
    await tester.tap(find.text('Subir de nuevo'));
    await tester.pumpAndSettle();
    expect(find.text('route:/service-credentials/new'), findsOneWidget);
  });

  testWidgets('withdraw asks first, then removes and refreshes',
      (tester) async {
    repo.mine = Right([credential(id: 'p')]);
    await open(tester);

    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Retirar esta constancia?'), findsOneWidget);

    // Cancelling does nothing.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('withdraw')), isEmpty);

    repo.mine = const Right([]);
    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();
    await tester.tap(dialogWithdraw());
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
    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();
    await tester.tap(dialogWithdraw());
    await tester.pumpAndSettle();
    expect(find.text('No encontramos esta constancia. Actualizamos la lista.'),
        findsOneWidget);
  });
}
