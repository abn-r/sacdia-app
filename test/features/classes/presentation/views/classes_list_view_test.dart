import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_status.dart';
import 'package:sacdia_app/features/certifications/domain/entities/user_certification.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_with_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/catalog/class_catalog.dart';
import 'package:sacdia_app/features/classes/presentation/catalog/class_catalog_providers.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/views/classes_list_view.dart';
import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';

const _enrolled = [
  ProgressiveClass(
    id: 13,
    name: 'Guía Mayor',
    clubTypeId: ProgressiveClass.masterGuidesClubTypeId,
    investitureStatus: 'IN_PROGRESS',
    ecclesiasticalYearLabel: '2025–2026',
  ),
  ProgressiveClass(
    id: 1,
    name: 'Amigo',
    clubTypeId: 2,
    investitureStatus: 'INVESTIDO',
  ),
];

const _sections = [
  ClassCatalogSection(clubTypeId: 1, entries: [
    ClassCatalogEntry(
      classId: 90,
      name: 'Corderitos',
      clubTypeId: 1,
      minAge: 6,
      maxAge: 6,
      status: ClassCatalogStatus.notInvested,
    ),
  ]),
  ClassCatalogSection(clubTypeId: 2, entries: [
    ClassCatalogEntry(
      classId: 1,
      name: 'Amigo',
      clubTypeId: 2,
      minAge: 10,
      maxAge: 15,
      status: ClassCatalogStatus.invested,
      year: '2012',
    ),
  ]),
  ClassCatalogSection(clubTypeId: 3, entries: [
    ClassCatalogEntry(
      classId: 13,
      name: 'Guía Mayor',
      clubTypeId: 3,
      minAge: 16,
      status: ClassCatalogStatus.inProgress,
      year: '2026',
      isCurrent: true,
    ),
  ]),
];

class _FakeAuth extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => const UserEntity(
        id: 'user-1',
        email: 'u@example.com',
        authorization: AuthorizationSnapshot(
          clubAssignments: [
            AuthorizationGrant(
              assignmentId: 'a1',
              status: 'active',
              sectionId: 5,
            ),
          ],
          activeAssignmentId: 'a1',
        ),
      );
}

final _enrollment = UserCertification(
  enrollmentId: 70,
  certificationId: 7,
  certificationName: 'Instructor de Conquistadores',
  enrollmentDate: DateTime(2026, 2, 1),
  completionStatus: 'in_progress',
  progressPercentage: 20,
  modulesCompleted: 0,
  modulesTotal: 8,
  active: true,
  status: CertificationEnrollmentStatus.inProgress,
);

Future<void> _pump(
  WidgetTester tester, {
  List<ProgressiveClass> classes = _enrolled,
  bool asScreen = false,
  bool eligibleForCertifications = true,
  List<UserCertification> certificationEnrollments = const [],
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => asScreen
            ? const ClassesListView()
            : const Scaffold(body: ClassesListViewBody()),
      ),
      GoRoute(
        path: RouteNames.homeClassesCatalog,
        builder: (_, __) => const Text('CATALOG ROUTE'),
      ),
      GoRoute(
        path: RouteNames.homeCertifications,
        builder: (_, __) => const Text('CERTIFICATIONS ROUTE'),
      ),
      GoRoute(
        path: RouteNames.certificationDetail,
        builder: (_, state) => Text(
          'CERTIFICATION ${state.pathParameters['certificationId']}',
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuth.new),
        certificationsAccessProvider.overrideWith(
          (ref) async =>
              eligibleForCertifications || certificationEnrollments.isNotEmpty,
        ),
        userCertificationsProvider.overrideWith(
          (ref) async => certificationEnrollments,
        ),
        userClassesProvider.overrideWith((ref) async => classes),
        classCatalogProvider.overrideWith((ref) async => _sections),
        classWithProgressProvider.overrideWith(
          (ref, query) async => const ClassWithProgress(
            id: 13,
            name: 'Guía Mayor',
            clubTypeId: 3,
            overallProgress: 28,
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadSpanishTranslations);

  testWidgets('current card: eyebrow, status, bar and percent, no ring/counts',
      (tester) async {
    await _pump(tester);

    expect(find.text('CLASE ACTUAL'), findsOneWidget);
    expect(find.text('Cursando · 2026'), findsWidgets);
    expect(find.byType(SacProgressBar), findsOneWidget);
    expect(find.text('28%'), findsOneWidget);
    expect(find.textContaining('requisitos'), findsNothing);
    expect(find.textContaining('por corregir'), findsNothing);
  });

  testWidgets('club lists: only clubs the user has classes in, with status',
      (tester) async {
    await _pump(tester);

    expect(find.text('CONQUISTADORES'), findsOneWidget);
    expect(find.text('10 a 15 años'), findsWidgets);
    expect(find.text('GUÍAS MAYORES'), findsOneWidget);
    expect(find.text('16+ años'), findsOneWidget);
    expect(find.text('AVENTUREROS'), findsNothing);
    expect(find.text('Investido · 2012'), findsOneWidget);
  });

  testWidgets('Explorar rows open the catalog and certifications',
      (tester) async {
    await _pump(tester);

    expect(find.text('EXPLORAR'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Todos los clubes y edades'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Clases por club'));
    await tester.pumpAndSettle();
    expect(find.text('CATALOG ROUTE'), findsOneWidget);

    tester.element(find.text('CATALOG ROUTE')).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Todas las certificaciones'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Certificaciones'));
    await tester.pumpAndSettle();
    expect(find.text('CERTIFICATIONS ROUTE'), findsOneWidget);
  });

  testWidgets('Explorar hides Certificaciones when the user is not eligible',
      (tester) async {
    await _pump(tester, eligibleForCertifications: false);

    expect(find.text('EXPLORAR'), findsOneWidget);
    expect(find.text('Clases por club'), findsOneWidget);
    expect(find.text('Todas las certificaciones'), findsNothing);
    expect(find.text('CERTIFICACIONES'), findsNothing);
  });

  testWidgets(
      'enrolled users get a Certificaciones group before Explorar, with the '
      'same row as the club classes', (tester) async {
    await _pump(
      tester,
      eligibleForCertifications: false,
      certificationEnrollments: [_enrollment],
    );

    await tester.scrollUntilVisible(
      find.text('Instructor de Conquistadores'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CERTIFICACIONES'), findsOneWidget);
    expect(find.text('8 módulos'), findsOneWidget);
    expect(find.text('En curso · 2026'), findsOneWidget);
    // Enrolled users always see the Explorar row too.
    expect(find.text('Todas las certificaciones'), findsOneWidget);
    final group = tester.getTopLeft(find.text('CERTIFICACIONES')).dy;
    final explore = tester.getTopLeft(find.text('EXPLORAR')).dy;
    expect(group, lessThan(explore));

    await tester.tap(find.text('Instructor de Conquistadores'));
    await tester.pumpAndSettle();
    expect(find.text('CERTIFICATION 7'), findsOneWidget);
  });

  testWidgets('the ⋯ menu offers "Inscribir clase anterior"', (tester) async {
    await _pump(tester, asScreen: true);

    expect(find.text('Mis clases'), findsOneWidget);
    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    expect(find.text('Inscribir clase anterior'), findsOneWidget);
  });

  testWidgets('without classes it keeps the empty state and Explorar',
      (tester) async {
    await _pump(tester, classes: const []);

    expect(find.text('No tienes clases asignadas'), findsOneWidget);
    expect(find.text('EXPLORAR'), findsOneWidget);
    expect(find.text('CLASE ACTUAL'), findsNothing);
  });
}
