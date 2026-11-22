import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_eligibility.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_progress.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_status.dart';
import 'package:sacdia_app/features/certifications/domain/entities/user_certification.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:sacdia_app/features/certifications/presentation/views/certification_view.dart';

import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';
import '../certification_test_support.dart';

const _allMet = CertificationEligibility(eligible: true, rules: [
  CertificationEligibilityRule(
    type: CertificationEligibilityRuleType.baptized,
    satisfied: true,
  ),
]);

const _notEligible = CertificationEligibility(eligible: false, rules: [
  CertificationEligibilityRule(
    type: CertificationEligibilityRuleType.minAge,
    satisfied: true,
  ),
  CertificationEligibilityRule(
    type: CertificationEligibilityRuleType.baptized,
    satisfied: false,
  ),
]);

/// Scrolls until [finder] is fully on screen (not only its edge).
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
  await tester.drag(scrollable, const Offset(0, -160));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  List<UserCertification> enrollments = const [],
  CertificationProgress? progress,
  CertificationEligibility eligibility = _allMet,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) =>
            const CertificationView(certificationId: kCertificationId),
      ),
      GoRoute(
        path: RouteNames.certificationModule,
        builder: (_, state) =>
            Text('MODULE ${state.pathParameters['moduleId']}'),
      ),
      GoRoute(
        path: RouteNames.certificationRequirementDetail,
        builder: (_, state) =>
            Text('REQUIREMENT ${state.pathParameters['sectionId']}'),
      ),
      GoRoute(
        path: RouteNames.certificationCloseout,
        builder: (_, __) => const Text('CLOSEOUT'),
      ),
    ],
  );
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(FakeCertificationAuth.new),
        userCertificationsProvider.overrideWith((ref) async => enrollments),
        certificationDetailProvider.overrideWith(
          (ref, id) async => sampleDetail(),
        ),
        certificationProgressProvider.overrideWith(
          (ref, id) async => progress ?? sampleProgress(),
        ),
        certificationEligibilityProvider.overrideWith(
          (ref, id) async => eligibility,
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadSpanishTranslations);

  group('enrolled', () {
    testWidgets('header, one summary box and «Por atender» like a class',
        (tester) async {
      await _pump(tester, enrollments: [sampleEnrollment()]);

      expect(find.text('Certificación'), findsOneWidget);
      expect(find.text('Instructor de Conquistadores'), findsWidgets);
      expect(find.text('En curso · 2026'), findsOneWidget);

      expect(find.text('Requisitos validados'), findsOneWidget);
      expect(find.textContaining('1 de 4', findRichText: true), findsOneWidget);
      expect(find.textContaining('faltan 3', findRichText: true), findsWidgets);
      expect(find.text('Avance de la certificación'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);

      expect(find.text('POR ATENDER'), findsOneWidget);
      final sentBack = tester.getTopLeft(find.text('Informe de actividad')).dy;
      final draft = tester.getTopLeft(find.text('Reflexión final')).dy;
      expect(sentBack, lessThan(draft), reason: 'to fix goes first');
      expect(find.textContaining('Devuelto el'), findsOneWidget);
      expect(find.text('Borrador guardado'), findsOneWidget);
    });

    testWidgets('modules are rows with their count; they open the module',
        (tester) async {
      await _pump(tester, enrollments: [sampleEnrollment()]);
      await _reveal(tester, find.text('Fundamentos'));

      expect(find.text('MÓDULOS'), findsOneWidget);
      expect(find.text('1 de 2'), findsOneWidget);
      expect(find.text('1 por corregir · 0 de 2'), findsOneWidget);

      await tester.tap(find.text('Fundamentos'));
      await tester.pumpAndSettle();
      expect(find.text('MODULE 1'), findsOneWidget);
    });

    testWidgets('a requirement of «Por atender» opens the requirement',
        (tester) async {
      await _pump(tester, enrollments: [sampleEnrollment()]);

      await tester.tap(find.text('Informe de actividad'));
      await tester.pumpAndSettle();
      expect(find.text('REQUIREMENT 21'), findsOneWidget);
    });

    testWidgets('«Cierre» is locked until every requirement is validated',
        (tester) async {
      await _pump(tester, enrollments: [sampleEnrollment()]);
      await _reveal(tester, find.text('Acta de la junta'));

      expect(find.text('CIERRE'), findsOneWidget);
      expect(
        find.text('Se abre cuando valides los 4 requisitos'),
        findsOneWidget,
      );
      await tester.tap(find.text('Acta de la junta'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('CLOSEOUT'), findsNothing);
    });

    testWidgets('«Cierre» opens once the enrollment is ready for it',
        (tester) async {
      await _pump(
        tester,
        enrollments: [
          sampleEnrollment(
              status: CertificationEnrollmentStatus.readyForCloseout),
        ],
        progress: sampleProgress(
          status: CertificationEnrollmentStatus.readyForCloseout,
        ),
      );
      await _reveal(tester, find.text('Acta de la junta'));

      expect(
          find.text('Sin enviar · sube el acta de la junta'), findsOneWidget);
      await tester.tap(find.text('Acta de la junta'));
      await tester.pumpAndSettle();
      expect(find.text('CLOSEOUT'), findsOneWidget);
    });

    testWidgets('the ⋯ menu has «Acerca de» and «Dejar» last', (tester) async {
      await _pump(tester, enrollments: [sampleEnrollment()]);

      await tester.tap(find.byKey(const ValueKey('certification-menu')));
      await tester.pumpAndSettle();

      final about = find.text('Acerca de esta certificación');
      final leave = find.text('Dejar la certificación');
      expect(about, findsOneWidget);
      expect(leave, findsOneWidget);
      expect(
        tester.getTopLeft(about).dy,
        lessThan(tester.getTopLeft(leave).dy),
      );

      await tester.tap(leave);
      await tester.pumpAndSettle();
      expect(find.text('¿Dejar la certificación?'), findsOneWidget);
      expect(find.byType(SacDialog), findsNothing);
    });

    testWidgets('a certified enrollment shows its date and the download row',
        (tester) async {
      await _pump(
        tester,
        enrollments: [
          sampleEnrollment(
            status: CertificationEnrollmentStatus.certified,
            certifiedAt: DateTime(2026, 3, 15),
          ),
        ],
        progress: sampleProgress(
          status: CertificationEnrollmentStatus.certified,
          certifiedAt: DateTime(2026, 3, 15),
          certificateUrl: 'https://example.com/certificate.pdf',
        ),
      );

      expect(find.textContaining('Certificada ·'), findsOneWidget);
      expect(find.text('Descargar certificado'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('certification-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Acerca de esta certificación'), findsOneWidget);
      expect(find.text('Dejar la certificación'), findsNothing);
    });
  });

  group('available', () {
    testWidgets('same screen with «Disponible», description and one action',
        (tester) async {
      await _pump(tester);

      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('Ver más'), findsOneWidget);
      expect(find.byKey(const ValueKey('certification-menu')), findsNothing);

      // Summary: what the certification asks.
      expect(find.text('Módulos'), findsWidgets);
      expect(find.text('Requisitos'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Revisa'), findsOneWidget);
      expect(find.text('Tu Campo Local'), findsOneWidget);

      final button = tester.widget<SacButton>(
        find.byKey(const ValueKey('certification-enroll')),
      );
      expect(button.isEnabled, isTrue);
      expect(find.text('Inscribirme'), findsOneWidget);
    });

    testWidgets('modules say how many requirements they have and open',
        (tester) async {
      await _pump(tester);
      await _reveal(tester, find.text('Fundamentos'));

      expect(find.text('2 requisitos'), findsOneWidget);
      expect(find.text('1 requisito'), findsOneWidget);
      await tester.tap(find.text('Fundamentos'));
      await tester.pumpAndSettle();
      expect(find.text('MODULE 1'), findsOneWidget);
    });

    testWidgets('«Ver más» opens the full description', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Ver más'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('certification-about-text')),
        findsOneWidget,
      );
      expect(
          find.textContaining('supervisado por el Campo Local'), findsWidgets);
    });

    testWidgets('«Inscribirme» confirms in a sheet, not in a red dialog',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('certification-enroll')));
      await tester.pumpAndSettle();

      expect(find.text('Inscribirte en esta certificación'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('certification-enroll-confirm')),
        findsOneWidget,
      );
      expect(find.byType(SacDialog), findsNothing);
    });

    testWidgets(
        'not eligible: the rules, each with a check or a clock, and a '
        'disabled button', (tester) async {
      await _pump(tester, eligibility: _notEligible);
      await _reveal(tester, find.text('Estar bautizado'));

      expect(find.text('REQUISITOS DE INSCRIPCIÓN'), findsOneWidget);
      expect(find.text('Tener la edad mínima'), findsOneWidget);
      expect(find.text('Cumples este requisito'), findsOneWidget);
      expect(find.text('Aún no cumples este requisito'), findsOneWidget);

      final button = tester.widget<SacButton>(
        find.byKey(const ValueKey('certification-enroll')),
      );
      expect(button.isEnabled, isFalse);
    });
  });
}
