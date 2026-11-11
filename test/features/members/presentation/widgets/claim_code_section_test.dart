import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/consent_verification_view.dart';
import 'package:sacdia_app/features/members/presentation/widgets/claim_code_section.dart';

import '../../members_test_support.dart';

JoinRequest _request({required bool custody}) => JoinRequest(
      assignmentId: '12/membership-requests/req-9',
      userId: 'luis-9',
      name: 'Luis',
      paternalSurname: 'Pérez',
      status: JoinRequestStatus.pending,
      requestedAt: DateTime(2026, 10, 12),
      consent: JoinRequestConsent(
        guardianshipId: 'gs-9',
        status: JoinRequestConsentStatus.pending,
        evidenceUploaded: true,
        dependent: true,
        guardianLinked: !custody,
        guardians: const [ConsentGuardianRef(displayName: 'Club ACV')],
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeMembersRepository repo;
  final clipboard = <String>[];

  setUp(() {
    repo = FakeMembersRepository();
    clipboard.clear();
  });

  Future<void> open(
    WidgetTester tester, {
    required JoinRequest request,
    bool canApprove = true,
  }) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpMembersApp(
      tester,
      overrides: [membersRepositoryProvider.overrideWithValue(repo)],
      home: ConsentVerificationView(
        request: request,
        canApprove: canApprove,
      ),
    );
    await tester.pumpAndSettle();
  }

  const action = 'Entregar a la familia';
  const hint = 'Código de un solo uso, vale 7 días';

  testWidgets('a custodial minor offers "generate parent code"',
      (tester) async {
    await open(tester, request: _request(custody: true));

    // One row inside the «Tutores» group, not a card with a big button.
    expect(find.text(action), findsOneWidget);
    expect(find.text(hint), findsOneWidget);
    expect(find.text('Custodia del club'), findsOneWidget);
    expect(find.text('Generar código para los padres'), findsNothing);
  });

  testWidgets('a minor with a linked guardian does not', (tester) async {
    await open(tester, request: _request(custody: false));

    expect(find.text(action), findsNothing);
  });

  testWidgets(
      'without club_members:approve the endpoint would 403, so it is hidden',
      (tester) async {
    await open(tester, request: _request(custody: true), canApprove: false);

    expect(find.text(action), findsNothing);
  });

  testWidgets(
      'generates for THIS section and minor, shows the XXXX-XXXX code, its '
      '7-day expiry, copy and share', (tester) async {
    await open(tester, request: _request(custody: true));

    await tester.ensureVisible(find.text(action));
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();

    expect(
        repo.claimCodeCalls, [(clubSectionId: 12, dependentUserId: 'luis-9')]);
    expect(find.text('Código para la familia'), findsOneWidget);
    expect(find.text('7KQ4-M9TX'), findsOneWidget);
    expect(find.textContaining('Vence'), findsOneWidget);
    expect(find.text('Compartir'), findsOneWidget);

    await tester.tap(find.text('Copiar código'));
    await tester.pumpAndSettle();
    expect(clipboard, ['7KQ4-M9TX']);
  });

  testWidgets('errors are mapped by code and never show the server text',
      (tester) async {
    repo.claimCodeResult = const Left(
      ServerFailure(
        message: 'raw server text',
        code: 409,
        errorCode: 'GUARDIANSHIP_ALREADY_GUARDIAN',
      ),
    );
    await open(tester, request: _request(custody: true));

    await tester.ensureVisible(find.text(action));
    await tester.tap(find.text(action));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('raw server text'), findsNothing);
    expect(find.text('7KQ4-M9TX'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pumpAndSettle();
  });

  for (final errorCase in <({String code, int status, String text})>[
    (
      code: 'GUARDIANSHIP_NOT_FOUND',
      status: 404,
      text: 'Este menor ya no tiene perfil en SACDIA porque su tutor lo '
          'eliminó. Rechaza la solicitud.',
    ),
    (
      code: 'GUARDIANSHIP_ALREADY_GUARDIAN',
      status: 409,
      text: 'Este menor ya tiene una familia vinculada. No hace falta '
          'entregarlo.',
    ),
  ]) {
    testWidgets('${errorCase.code} explains what happened to the director',
        (tester) async {
      repo.claimCodeResult = Left(
        ServerFailure(
          message: 'raw server text',
          code: errorCase.status,
          errorCode: errorCase.code,
        ),
      );
      await open(tester, request: _request(custody: true));

      await tester.ensureVisible(find.text(action));
      await tester.tap(find.text(action));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(errorCase.text), findsOneWidget);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('a code-less 429 says too many attempts', (tester) async {
    repo.claimCodeResult = const Left(ServerFailure(message: 'x', code: 429));
    await open(tester, request: _request(custody: true));

    await tester.ensureVisible(find.text(action));
    await tester.tap(find.text(action));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
        find.text('Demasiados intentos. Inténtalo más tarde.'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets(
      'at phone width (402x874, real text size) the row text is complete: '
      'no ellipsis, no overflow, tap target of 44pt or more, full accessibility '
      'label', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpMembersApp(
      tester,
      size: const Size(402, 874),
      textScale: 1.0,
      overrides: [membersRepositoryProvider.overrideWithValue(repo)],
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: ClaimCodeSection(
            clubSectionId: 12,
            dependentUserId: 'luis-9',
            dependentName: 'Luis',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final text in [action, hint]) {
      final label = tester.renderObject<RenderParagraph>(find.text(text));
      expect(label.didExceedMaxLines, isFalse,
          reason: 'the text must wrap, not be cut with an ellipsis');
    }
    expect(tester.getSize(find.byType(ClaimCodeSection)).height,
        greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSemantics(find.text(action)).label,
      contains(action),
    );
    semantics.dispose();
  });
}
