import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_status.dart';
import 'package:sacdia_app/features/certifications/domain/entities/user_certification.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:sacdia_app/features/certifications/presentation/views/certifications_list_view.dart';

import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';
import '../certification_test_support.dart';

const _catalog = [
  Certification(
    certificationId: 7,
    name: 'Instructor de Conquistadores',
    active: true,
    modulesCount: 8,
    requirementsCount: 19,
  ),
  Certification(
    certificationId: 8,
    name: 'Director de Club',
    active: true,
    modulesCount: 5,
  ),
  Certification(
    certificationId: 9,
    name: 'Consejero de Menores',
    active: true,
    modulesCount: 1,
    requirementsCount: 1,
  ),
  Certification(
    certificationId: 10,
    name: 'Certificación retirada',
    active: false,
    modulesCount: 3,
  ),
];

UserCertification _enrollment(
  int certificationId,
  String name,
  CertificationEnrollmentStatus status,
) =>
    UserCertification(
      enrollmentId: 100 + certificationId,
      certificationId: certificationId,
      certificationName: name,
      enrollmentDate: DateTime(2025, 4, 1),
      completionStatus: 'in_progress',
      progressPercentage: 0,
      modulesCompleted: 0,
      modulesTotal: 8,
      active: true,
      status: status,
      certifiedAt: status.isCertified ? DateTime(2025, 11, 20) : null,
    );

Future<void> _pump(
  WidgetTester tester, {
  List<UserCertification> enrollments = const [],
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const CertificationsListView()),
      GoRoute(
        path: RouteNames.certificationDetail,
        builder: (_, state) =>
            Text('CERTIFICATION ${state.pathParameters['certificationId']}'),
      ),
    ],
  );
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(FakeCertificationAuth.new),
        certificationsProvider.overrideWith((ref) async => _catalog),
        userCertificationsProvider.overrideWith((ref) async => enrollments),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadSpanishTranslations);

  testWidgets(
      'groups «En curso», «Disponibles» and «Certificadas» like «Clases por '
      'club», with their count', (tester) async {
    await _pump(tester, enrollments: [
      _enrollment(
        7,
        'Instructor de Conquistadores',
        CertificationEnrollmentStatus.inProgress,
      ),
      _enrollment(
        9,
        'Consejero de Menores',
        CertificationEnrollmentStatus.certified,
      ),
    ]);

    expect(find.text('EN CURSO'), findsOneWidget);
    expect(find.text('DISPONIBLES'), findsOneWidget);
    expect(find.text('CERTIFICADAS'), findsOneWidget);
    expect(find.text('En curso · 2025'), findsOneWidget);
    expect(find.text('Certificada · 2025'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    // Unpublished certifications never show.
    expect(find.text('Certificación retirada'), findsNothing);
  });

  testWidgets('rows: name, «8 módulos · 19 requisitos» and no enroll button',
      (tester) async {
    await _pump(tester);

    expect(find.text('8 módulos · 19 requisitos'), findsOneWidget);
    // No requirement total from the server: only the modules.
    expect(find.text('5 módulos'), findsOneWidget);
    expect(find.text('1 módulo · 1 requisito'), findsOneWidget);
    expect(find.text('Inscribirme'), findsNothing);
    expect(find.text('DISPONIBLES'), findsOneWidget);
    expect(find.text('EN CURSO'), findsNothing);
    expect(find.text('CERTIFICADAS'), findsNothing);
  });

  testWidgets('a row opens the certification by route', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Director de Club'));
    await tester.pumpAndSettle();
    expect(find.text('CERTIFICATION 8'), findsOneWidget);
  });

  testWidgets('a withdrawn enrollment leaves the certification available',
      (tester) async {
    await _pump(tester, enrollments: [
      _enrollment(
        7,
        'Instructor de Conquistadores',
        CertificationEnrollmentStatus.withdrawn,
      ),
    ]);

    expect(find.text('EN CURSO'), findsNothing);
    expect(find.text('DISPONIBLES'), findsOneWidget);
  });
}
