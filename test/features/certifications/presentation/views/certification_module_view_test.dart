import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/certifications/domain/entities/user_certification.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:sacdia_app/features/certifications/presentation/views/certification_module_view.dart';

import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';
import '../certification_test_support.dart';

Future<void> _pump(
  WidgetTester tester, {
  required int moduleId,
  List<UserCertification> enrollments = const [],
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => CertificationModuleView(
          certificationId: kCertificationId,
          moduleId: moduleId,
        ),
      ),
      GoRoute(
        path: RouteNames.certificationRequirementDetail,
        builder: (_, state) =>
            Text('REQUIREMENT ${state.pathParameters['sectionId']}'),
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
          (ref, id) async => sampleProgress(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadSpanishTranslations);

  testWidgets('title, «X de Y validados» and the box with its bar',
      (tester) async {
    await _pump(tester, moduleId: 1, enrollments: [sampleEnrollment()]);

    expect(find.text('Fundamentos'), findsOneWidget);
    expect(find.text('1 de 2 validados'), findsOneWidget);
    expect(find.byKey(const ValueKey('certification-module-summary')),
        findsOneWidget);
  });

  testWidgets('requirements are grouped by state; empty groups are left out',
      (tester) async {
    await _pump(tester, moduleId: 1, enrollments: [sampleEnrollment()]);

    expect(find.text('ENVIADOS'), findsOneWidget);
    expect(find.text('VALIDADOS'), findsOneWidget);
    expect(find.text('POR CORREGIR'), findsNothing);
    expect(find.text('SIN ENVIAR'), findsNothing);
    expect(find.text('Plan de trabajo'), findsOneWidget);
    expect(find.text('Historia del club'), findsOneWidget);
  });

  testWidgets('to fix goes before not sent, and a requirement opens',
      (tester) async {
    await _pump(tester, moduleId: 2, enrollments: [sampleEnrollment()]);

    expect(find.text('0 de 2 validados'), findsOneWidget);
    final toFix = tester.getTopLeft(find.text('POR CORREGIR')).dy;
    final unsent = tester.getTopLeft(find.text('SIN ENVIAR')).dy;
    expect(toFix, lessThan(unsent));
    expect(find.text('ENVIADOS'), findsNothing);

    await tester.tap(find.text('Reflexión final'));
    await tester.pumpAndSettle();
    expect(find.text('REQUIREMENT 22'), findsOneWidget);
  });

  testWidgets('before enrolling it lists the requirements read-only',
      (tester) async {
    await _pump(tester, moduleId: 1);

    expect(find.text('2 requisitos'), findsOneWidget);
    expect(find.text('Historia del club'), findsOneWidget);
    expect(find.text('Plan de trabajo'), findsOneWidget);
    // No status groups, nothing to open.
    expect(find.text('POR CORREGIR'), findsNothing);
    expect(find.text('ENVIADOS'), findsNothing);
    await tester.tap(find.text('Plan de trabajo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('REQUIREMENT'), findsNothing);
  });

  testWidgets('an unknown module says so', (tester) async {
    await _pump(tester, moduleId: 99, enrollments: [sampleEnrollment()]);

    expect(find.byKey(const ValueKey('certification-module-not-found')),
        findsOneWidget);
  });
}
