import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent_progress_summary.dart';
import 'package:sacdia_app/features/family/presentation/family_error_messages.dart';
import 'package:sacdia_app/features/family/presentation/family_outcome_messages.dart';
import 'package:sacdia_app/features/family/presentation/views/guardian_summary_view.dart';

import 'family_fixtures.dart';
import 'family_test_harness.dart';

DependentProgressSummary _summary({
  List<ClassProgressSummary>? classes,
  AttendanceSummary? attendance,
}) =>
    DependentProgressSummary(
      userId: 'ana-1',
      name: 'Ana',
      age: 14,
      supervisedLogin: true,
      classes: classes ??
          const [
            ClassProgressSummary(
              classId: 3,
              name: 'Amigo',
              progressPercent: 62,
              sectionsCompleted: 5,
              sectionsTotal: 8,
            ),
            ClassProgressSummary(
              classId: 4,
              name: 'Compañero',
              progressPercent: 0,
              sectionsCompleted: 0,
              sectionsTotal: 6,
            ),
          ],
      honorsCompleted: 3,
      honorsInProgress: 2,
      attendance: attendance ??
          AttendanceSummary(
            from: DateTime.utc(2026, 1, 1),
            to: DateTime.utc(2026, 10, 19),
            activitiesTotal: 12,
            activitiesAttended: 9,
          ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeFamilyRepository repo;

  setUp(() => repo = FakeFamilyRepository());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = await pumpFamilyApp(
      tester,
      overrides: familyOverrides(repo: repo, auth: FakeAuthNotifier()),
      initialLocation: '/family',
      routes: [
        stubRoute('/family'),
        GoRoute(
          path: '/family/:dependentId/summary',
          builder: (_, state) => GuardianSummaryView(
            dependentId: state.pathParameters['dependentId']!,
          ),
        ),
      ],
    );
    router.push('/family/ana-1/summary');
    await tester.pumpAndSettle();
  }

  testWidgets('shows classes, honors and attendance for the dependent',
      (tester) async {
    repo.progress = Right(_summary());
    await pump(tester);

    expect(repo.summaryCalls, ['ana-1']);
    expect(find.text('Resumen de Ana'), findsOneWidget);
    expect(find.text('Amigo'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('5 de 8 secciones'), findsOneWidget);
    expect(find.text('Compañero'), findsOneWidget);
    expect(find.text('3 completadas'), findsOneWidget);
    expect(find.text('2 en curso'), findsOneWidget);
    expect(find.text('9 de 12 actividades'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.textContaining('Del '), findsOneWidget);
  });

  testWidgets('says what it does NOT include: health and notes',
      (tester) async {
    repo.progress = Right(_summary());
    await pump(tester);

    expect(
      find.text('Este resumen no incluye información de salud ni notas personales.'),
      findsOneWidget,
    );
  });

  testWidgets('no health or contact section is ever rendered', (tester) async {
    repo.progress = Right(_summary());
    await pump(tester);

    for (final forbidden in [
      'Alergias',
      'Enfermedades',
      'Medicamentos',
      'Contactos de emergencia',
      'Información médica',
      'Tipo de sangre',
    ]) {
      expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
    }
  });

  testWidgets('empty states for no classes and no activities', (tester) async {
    repo.progress = Right(
      _summary(classes: const [], attendance: const AttendanceSummary()),
    );
    await pump(tester);

    expect(find.text('Aún no tiene clases en curso.'), findsOneWidget);
    expect(find.text('Sin actividades en este periodo.'), findsOneWidget);
  });

  group('errors are explained by code', () {
    testWidgets('a pending guardian (409) is told consent is not verified',
        (tester) async {
      repo.progress = const Left(
        ServerFailure(
          message: 'RAW',
          code: 409,
          errorCode: 'GUARDIANSHIP_CONSENT_NOT_VERIFIED',
        ),
      );
      await pump(tester);

      expect(
        find.text(
          'El consentimiento aún no está verificado. Un director debe '
          'confirmarlo primero.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('RAW'), findsNothing);
      // No se arregla reintentando: solo volver.
      expect(find.text('Reintentar'), findsNothing);
      expect(find.text('Volver'), findsOneWidget);
    });

    testWidgets('a stranger (404) gets the not-found message', (tester) async {
      repo.progress = const Left(
        ServerFailure(
          message: 'RAW',
          code: 404,
          errorCode: 'GUARDIANSHIP_NOT_FOUND',
        ),
      );
      await pump(tester);

      expect(find.text('No encontramos a este menor.'), findsOneWidget);
      expect(find.text('Volver'), findsOneWidget);
    });

    testWidgets('a network failure can be retried', (tester) async {
      repo.progress = const Left(NetworkFailure(message: 'offline'));
      await pump(tester);

      expect(find.text('Error de conexión. Compruebe su red.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      repo.progress = Right(_summary());
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Amigo'), findsOneWidget);
      expect(repo.summaryCalls, hasLength(2));
    });
  });

  group('outcome and error copy for the 3a codes', () {
    test(
        'a leaving guardian of a teen with an own login is told '
        'pending_guardian, never frozen', () {
      final detail = DependentDetail(
        summary: summary(
          age: 15,
          consent: 'verified',
          accessMode: AccessMode.supervisedLogin,
        ),
        guardians: const [],
      );
      expect(predictLeaveOutcome(detail), DependentOutcome.pendingGuardian);
    });

    test('a child without an account is still frozen', () {
      final detail = DependentDetail(
        summary: summary(consent: 'verified'),
        guardians: const [],
      );
      expect(predictLeaveOutcome(detail), DependentOutcome.frozen);
    });

    test('every 3a code is a family code with a translated message', () {
      const codes = [
        'SUPERVISED_LOGIN_NOT_ELIGIBLE',
        'SUPERVISED_LOGIN_AGE_OUT_OF_RANGE',
        'SUPERVISED_LOGIN_ALREADY_ENABLED',
        'SUPERVISED_LOGIN_NOT_FOUND',
        'SUPERVISED_LOGIN_EMAIL_UNAVAILABLE',
        'SUPERVISED_LOGIN_PASSWORD_INVALID',
        'GUARDIANSHIP_CONSENT_NOT_VERIFIED',
        'FAMILY_FEATURE_DISABLED',
        'PRINCIPAL_SCOPE_DENIED',
      ];
      for (final locale in ['es', 'en', 'fr', 'pt-BR']) {
        final json = jsonDecode(
          File('assets/translations/$locale.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        final errors = json['errors'] as Map<String, dynamic>;
        for (final code in codes) {
          expect(familyErrorCodes, contains(code));
          expect(familyErrorKey(code), 'errors.${code.toLowerCase()}');
          expect(errors[code.toLowerCase()], isA<String>(),
              reason: '$code in $locale');
        }
      }
    });
  });

  testWidgets('the pending_guardian outcome reads in the delete/leave dialogs',
      (tester) async {
    late String text;
    await pumpFamilyApp(
      tester,
      overrides: const [],
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) {
            text = outcomeMessage(DependentOutcome.pendingGuardian, 'Ana');
            return const SizedBox();
          },
        ),
      ],
    );

    expect(text, contains('Ana'));
    expect(text, contains('90 días'));
  });
}
