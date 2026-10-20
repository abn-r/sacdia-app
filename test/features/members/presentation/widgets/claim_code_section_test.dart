import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/consent_verification_view.dart';

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

  const action = 'Generar código para los padres';

  testWidgets('a custodial minor offers "generate parent code"',
      (tester) async {
    await open(tester, request: _request(custody: true));

    expect(find.text('Entregar a la familia'), findsOneWidget);
    expect(find.text(action), findsOneWidget);
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

  testWidgets('a code-less 429 says too many attempts', (tester) async {
    repo.claimCodeResult = const Left(ServerFailure(message: 'x', code: 429));
    await open(tester, request: _request(custody: true));

    await tester.ensureVisible(find.text(action));
    await tester.tap(find.text(action));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
        find.text('Demasiados intentos. Intente más tarde.'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
