import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/access_denied_view.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/features/service_credentials/domain/entities/service_credential.dart';
import 'package:sacdia_app/features/service_credentials/presentation/views/service_credential_review_detail_view.dart';
import 'package:sacdia_app/features/service_credentials/presentation/widgets/service_credentials_skeleton.dart';

import '../service_credentials_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeServiceCredentialsRepository repo;
  setUp(() => repo = FakeServiceCredentialsRepository());

  /// The detail is pushed over a home screen so a successful decision can pop.
  Future<void> open(
    WidgetTester tester, {
    bool allowed = true,
    bool settle = true,
  }) async {
    final router = await pumpCredentialsApp(
      tester,
      home: const Scaffold(body: Text('home')),
      overrides: credentialOverrides(
        repo,
        user: adultUser(capabilities: [if (allowed) reviewerCapability]),
      ),
      routes: [
        GoRoute(
          path: '/service-credentials/review/:credentialId',
          builder: (_, state) => ServiceCredentialReviewDetailView(
            id: state.pathParameters['credentialId']!,
          ),
        ),
      ],
    );
    unawaited(router.push('/service-credentials/review/c1'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }

  Finder sheetButton(String label) =>
      find.widgetWithText(SacButton, label).last;

  testWidgets('without the capability it is denied and loads nothing',
      (tester) async {
    await open(tester, allowed: false);
    expect(find.byType(AccessDeniedView), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('shows a skeleton while loading', (tester) async {
    repo.detailGate = Completer<void>();
    await open(tester, settle: false);
    expect(find.byType(ServiceCredentialsSkeleton), findsOneWidget);
    repo.detailGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows person, club, credential, dates and the file card',
      (tester) async {
    await open(tester);
    expect(find.text('Laura Méndez'), findsOneWidget);
    expect(find.text('Club Pionero'), findsOneWidget);
    expect(find.text('Curso de consejería (10 horas)'), findsOneWidget);
    expect(find.text('14 mar 2026'), findsOneWidget); // completion date
    expect(find.text('1 abr 2026'), findsOneWidget); // sent date
    expect(find.text('Abrir documento'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.widgetWithText(SacButton, 'Aprobar'), findsOneWidget);
    expect(find.widgetWithText(SacButton, 'Rechazar'), findsOneWidget);
  });

  testWidgets('an image is previewed inline and a missing file is explained',
      (tester) async {
    repo.detailResult = Right(reviewDetail(
      fileUrl: 'https://files.example/c1.png?sig=abc',
      mimeType: 'image/png',
    ));
    await open(tester);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Abrir documento'), findsOneWidget);
  });

  testWidgets('a credential without document says so', (tester) async {
    repo.detailResult = Right(reviewDetail(fileUrl: null, mimeType: null));
    await open(tester);
    expect(find.text('Esta constancia no tiene documento disponible.'),
        findsOneWidget);
  });

  testWidgets('approve without expiry confirms, calls the API and goes back',
      (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(SacButton, 'Aprobar'));
    await tester.pumpAndSettle();
    expect(find.text('Aprobar constancia'), findsOneWidget);
    expect(find.text('Sin fecha, la constancia no vence.'), findsOneWidget);

    await tester.tap(sheetButton('Aprobar'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('approve:c1'));
    expect(repo.lastExpiresAt, isNull);
    expect(find.text('Constancia aprobada.'), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('approve with an expiry date sends it', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(SacButton, 'Aprobar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seleccionar fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();

    await tester.tap(sheetButton('Aprobar'));
    await tester.pumpAndSettle();
    expect(repo.lastExpiresAt, isNotNull);
  });

  testWidgets('reject needs a reason of at least 5 characters', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(SacButton, 'Rechazar'));
    await tester.pumpAndSettle();
    expect(find.text('Rechazar constancia'), findsOneWidget);

    SacButton confirm() => tester.widget<SacButton>(sheetButton('Rechazar'));
    expect(confirm().onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'abc');
    await tester.pump();
    expect(confirm().onPressed, isNull);
    expect(find.text('Escribe un motivo de al menos 5 caracteres.'),
        findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '   ab   ');
    await tester.pump();
    expect(confirm().onPressed, isNull);

    await tester.enterText(
        find.byType(TextField).last, '  Documento ilegible ');
    await tester.pump();
    expect(confirm().onPressed, isNotNull);

    await tester.tap(sheetButton('Rechazar'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('reject:c1'));
    expect(repo.lastReason, 'Documento ilegible');
    expect(find.text('Constancia rechazada.'), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('dismissing the reject sheet calls nothing', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(SacButton, 'Rechazar'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('reject')), isEmpty);
  });

  testWidgets('already reviewed (409): mapped message, stays, reloads',
      (tester) async {
    repo.approveResult = const Left(ServerFailure(
      message: 'raw',
      code: 409,
      errorCode: 'SERVICE_CREDENTIAL_NOT_PENDING',
    ));
    await open(tester);
    repo.calls.clear();
    await tester.tap(find.widgetWithText(SacButton, 'Aprobar'));
    await tester.pumpAndSettle();
    await tester.tap(sheetButton('Aprobar'));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Esta constancia ya fue revisada por otra persona. Actualizamos la lista.'),
      findsOneWidget,
    );
    expect(find.text('raw'), findsNothing);
    expect(find.text('home'), findsNothing);
    expect(repo.calls, contains('detail:c1'));
  });

  testWidgets('self review is blocked with its own message', (tester) async {
    repo.rejectResult = const Left(ServerFailure(
      message: 'raw',
      code: 403,
      errorCode: 'SERVICE_CREDENTIAL_SELF_REVIEW',
    ));
    await open(tester);
    await tester.tap(find.widgetWithText(SacButton, 'Rechazar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Motivo válido');
    await tester.pump();
    await tester.tap(sheetButton('Rechazar'));
    await tester.pumpAndSettle();
    expect(
        find.text('No puedes revisar tu propia constancia.'), findsOneWidget);
  });

  testWidgets('a decided credential shows its outcome and no actions',
      (tester) async {
    repo.detailResult = Right(reviewDetail(
      item: reviewItem(status: ServiceCredentialStatus.rejected),
      reason: 'Documento ilegible',
    ));
    await open(tester);
    expect(find.text('Motivo: Documento ilegible'), findsOneWidget);
    expect(find.text('Rechazada'), findsOneWidget);
    expect(find.widgetWithText(SacButton, 'Aprobar'), findsNothing);
    expect(find.widgetWithText(SacButton, 'Rechazar'), findsNothing);
  });

  testWidgets('an approved credential shows its expiry and no actions',
      (tester) async {
    repo.detailResult = Right(reviewDetail(
      item: reviewItem(status: ServiceCredentialStatus.approved),
      expiresAt: DateTime(2027, 5, 20),
    ));
    await open(tester);
    expect(find.textContaining('Vigente hasta'), findsOneWidget);
    expect(find.widgetWithText(SacButton, 'Aprobar'), findsNothing);
  });

  testWidgets('not found: error state with retry', (tester) async {
    repo.detailResult = const Left(ServerFailure(
      message: 'x',
      code: 404,
      errorCode: 'SERVICE_CREDENTIAL_NOT_FOUND',
    ));
    await open(tester);
    expect(find.byType(SacErrorState), findsOneWidget);
    expect(find.text('No encontramos esta constancia. Actualizamos la lista.'),
        findsOneWidget);

    repo.detailResult = Right(reviewDetail());
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Laura Méndez'), findsOneWidget);
  });
}
