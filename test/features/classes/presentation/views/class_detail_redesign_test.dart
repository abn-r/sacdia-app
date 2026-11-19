import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_module_detail.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_requirement.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_with_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/domain/entities/requirement_evidence.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/views/class_detail_with_progress_view.dart';
import 'package:sacdia_app/features/classes/presentation/views/class_module_view.dart';
import 'package:sacdia_app/features/classes/presentation/widgets/requirement_card.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/providers/investiture_requests_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

import '../../../../support/riverpod_test_support.dart';
import '../../../investiture_requests/fake_investiture_requests_repository.dart';
import '../grouped_class_test_support.dart';

ClassRequirement _req(
  int id,
  String name,
  RequirementStatus status, {
  int moduleId = 1,
  int files = 0,
  DateTime? rejectedAt,
  String? honor,
}) =>
    ClassRequirement(
      id: id,
      name: name,
      moduleId: moduleId,
      status: status,
      rejectedAt: rejectedAt,
      linkedHonorName: honor,
      files: [
        for (var i = 0; i < files; i++)
          RequirementEvidence(
            id: '$id-$i',
            url: 'https://example.com/$id-$i.jpg',
            fileName: 'f$i.jpg',
            type: EvidenceFileType.image,
            uploadedByName: 'Ana',
            uploadedAt: DateTime(2026, 11, 1),
          ),
      ],
    );

ClassWithProgress _class(List<ClassModuleDetail> modules) => ClassWithProgress(
      id: 5,
      name: 'Guía Mayor',
      clubTypeId: 3,
      enrollmentId: 55,
      investitureStatus: 'IN_PROGRESS',
      overallProgress: 28,
      modules: modules,
    );

final _modules = [
  ClassModuleDetail(
    id: 1,
    name: 'Prerrequisitos',
    classId: 5,
    requirements: [
      _req(1, 'Presentar un sermón', RequirementStatus.rechazado,
          rejectedAt: DateTime(2026, 11, 15)),
      _req(2, 'Leer El Camino a Cristo', RequirementStatus.pendiente, files: 2),
      _req(3, 'Ministerio de los Aventureros', RequirementStatus.pendiente),
      _req(4, 'Armar una casa de campaña', RequirementStatus.enviado),
      _req(5, 'Tener una recomendación', RequirementStatus.validado),
    ],
  ),
  ClassModuleDetail(
    id: 2,
    name: 'Desarrollo espiritual',
    classId: 5,
    requirements: [
      _req(6, 'Campamento de liderazgo', RequirementStatus.observado,
          moduleId: 2, rejectedAt: DateTime(2026, 11, 12)),
      _req(7, 'Serie Encuentro I', RequirementStatus.pendiente, moduleId: 2),
    ],
  ),
];

List<Override> _overrides(ClassWithProgress Function() data) => [
      investitureRequestsRepositoryProvider
          .overrideWithValue(FakeInvestitureRequestsRepository()),
      classWithProgressProvider.overrideWith((ref, query) async => data()),
      classDetailProvider.overrideWith(
        (ref, classId) async =>
            const ProgressiveClass(id: 5, name: 'Guía Mayor', clubTypeId: 3),
      ),
      classHonorsProvider.overrideWith((ref, classId) async => const []),
      clubContextProvider.overrideWith(
        (ref) async => const ClubContext(clubId: 1, sectionId: 4),
      ),
    ];

Future<void> _pump(
  WidgetTester tester, {
  required String initial,
  required ClassWithProgress Function() data,
}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: RouteNames.classDetail,
        builder: (_, state) => ClassDetailWithProgressView(
          classId: 5,
          enrollmentId: int.tryParse(
            state.uri.queryParameters['enrollmentId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.classModule,
        builder: (_, state) => ClassModuleView(
          classId: 5,
          moduleId: int.parse(state.pathParameters['moduleId']!),
          enrollmentId: int.tryParse(
            state.uri.queryParameters['enrollmentId'] ?? '',
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    testProviderScope(
      overrides: _overrides(data),
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUpAll(initGroupedClassL10n);

  group('class screen', () {
    testWidgets('one summary box replaces the status pills', (tester) async {
      await _pump(
        tester,
        initial: RouteNames.classDetailPath('5', enrollmentId: 55),
        data: () => _class(_modules),
      );

      expect(find.byKey(const ValueKey('class-summary')), findsOneWidget);
      expect(find.textContaining('1 de 7', findRichText: true), findsOneWidget);
      expect(
          find.textContaining('faltan 6', findRichText: true), findsOneWidget);
      expect(find.textContaining('1 validado'), findsOneWidget);
      expect(find.textContaining('1 enviado'), findsOneWidget);
      expect(find.textContaining('2 por corregir'), findsOneWidget);
      expect(find.textContaining('3 sin enviar'), findsOneWidget);
      // The old pills are gone.
      expect(find.text('Observados'), findsNothing);
      expect(find.text('Pendientes'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('"por atender" lists sent back first, then started',
        (tester) async {
      await _pump(
        tester,
        initial: RouteNames.classDetailPath('5', enrollmentId: 55),
        data: () => _class(_modules),
      );

      final section = find.byKey(const ValueKey('class-attention-section'));
      expect(section, findsOneWidget);
      Finder inSection(String text) =>
          find.descendant(of: section, matching: find.text(text));

      final fix1 = tester.getTopLeft(inSection('Presentar un sermón')).dy;
      final fix2 = tester.getTopLeft(inSection('Campamento de liderazgo')).dy;
      final started =
          tester.getTopLeft(inSection('Leer El Camino a Cristo')).dy;
      expect(fix1, lessThan(fix2));
      expect(fix2, lessThan(started));
      expect(inSection('2 archivos sin enviar'), findsOneWidget);
      expect(inSection('Devuelto el 15 nov'), findsOneWidget);
      // Not sent and without files does not need attention yet.
      expect(inSection('Ministerio de los Aventureros'), findsNothing);
      expect(inSection('Armar una casa de campaña'), findsNothing);
    });

    testWidgets('"por atender" is hidden when nothing needs it',
        (tester) async {
      await _pump(
        tester,
        initial: RouteNames.classDetailPath('5', enrollmentId: 55),
        data: () => _class([
          ClassModuleDetail(
            id: 1,
            name: 'Prerrequisitos',
            classId: 5,
            requirements: [
              _req(1, 'Uno', RequirementStatus.validado),
              _req(2, 'Dos', RequirementStatus.pendiente),
            ],
          ),
        ]),
      );

      expect(
          find.byKey(const ValueKey('class-attention-section')), findsNothing);
      expect(
          find.byKey(const ValueKey('class-modules-section')), findsOneWidget);
    });

    testWidgets('module rows show the count and open the module screen',
        (tester) async {
      await _pump(
        tester,
        initial: RouteNames.classDetailPath('5', enrollmentId: 55),
        data: () => _class(_modules),
      );

      final row = find.byKey(const ValueKey('class-module-1'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Prerrequisitos')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: row, matching: find.textContaining('1 por corregir')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('1 de 5')),
        findsOneWidget,
      );
      // No accordion: the requirements of a module are not inside its row.
      expect(
        find.descendant(
            of: row, matching: find.text('Ministerio de los Aventureros')),
        findsNothing,
      );

      await tester.ensureVisible(row);
      await tester.tap(row);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(find.byType(ClassModuleView), findsOneWidget);
      expect(find.byKey(const ValueKey('module-summary')), findsOneWidget);
    });
  });

  group('module screen', () {
    testWidgets('groups by state in order and skips the empty ones',
        (tester) async {
      await _pump(
        tester,
        initial: RouteNames.classModulePath('5', '1', enrollmentId: 55),
        data: () => _class(_modules),
      );

      Finder group(String name) => find.byKey(ValueKey('module-group-$name'));
      expect(group('toFix'), findsOneWidget);
      expect(group('unsent'), findsOneWidget);
      expect(group('sent'), findsOneWidget);
      expect(group('validated'), findsOneWidget);

      final ys = [
        for (final g in ['toFix', 'unsent', 'sent', 'validated'])
          tester.getTopLeft(group(g)).dy,
      ];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.text('POR CORREGIR'), findsOneWidget);
      expect(find.text('SIN ENVIAR'), findsOneWidget);
      expect(find.text('ENVIADOS'), findsOneWidget);
      expect(find.text('VALIDADOS'), findsOneWidget);
      expect(
          find.descendant(
            of: find.byKey(const ValueKey('module-summary')),
            matching: find.textContaining('1 de 5', findRichText: true),
          ),
          findsOneWidget);

      // Module 2 has nothing sent or validated.
      await _pump(
        tester,
        initial: RouteNames.classModulePath('5', '2', enrollmentId: 55),
        data: () => _class(_modules),
      );
      expect(group('toFix'), findsOneWidget);
      expect(group('unsent'), findsOneWidget);
      expect(group('sent'), findsNothing);
      expect(group('validated'), findsNothing);
      expect(find.text('ENVIADOS'), findsNothing);
      expect(find.text('Campamento de liderazgo'), findsOneWidget);
    });

    testWidgets('an unknown module says so', (tester) async {
      await _pump(
        tester,
        initial: RouteNames.classModulePath('5', '99', enrollmentId: 55),
        data: () => _class(_modules),
      );

      expect(find.byKey(const ValueKey('module-not-found')), findsOneWidget);
    });

    testWidgets('same icon and tone per state in the list', (tester) async {
      await _pump(
        tester,
        initial: RouteNames.classModulePath('5', '1', enrollmentId: 55),
        data: () => _class(_modules),
      );

      HugeIconData iconOf(int id) {
        final icon = find.descendant(
          of: find.byKey(ValueKey('grouped-requirement-$id')),
          matching: find.byType(HugeIcon),
        );
        return tester.widget<HugeIcon>(icon.first).icon;
      }

      expect(iconOf(1), HugeIcons.strokeRoundedAlertCircle); // por corregir
      expect(iconOf(3), HugeIcons.strokeRoundedFolder01); // sin enviar
      expect(iconOf(4), HugeIcons.strokeRoundedSent); // enviado
      expect(iconOf(5), HugeIcons.strokeRoundedCheckmarkCircle02); // validado
      expect(find.byType(RequirementCard), findsNWidgets(5));
    });

    testWidgets('an honor-linked requirement names the honor', (tester) async {
      await _pump(
        tester,
        initial: RouteNames.classModulePath('5', '1', enrollmentId: 55),
        data: () => _class([
          ClassModuleDetail(
            id: 1,
            name: 'Prerrequisitos',
            classId: 5,
            requirements: [
              _req(1, 'Completar una especialidad', RequirementStatus.pendiente,
                  honor: 'Amarres'),
            ],
          ),
        ]),
      );

      expect(find.text('Especialidad: Amarres'), findsOneWidget);
    });

    testWidgets('re-reads the class when the progress is invalidated',
        (tester) async {
      var data = _class(_modules);
      await _pump(
        tester,
        initial: RouteNames.classModulePath('5', '2', enrollmentId: 55),
        data: () => data,
      );
      expect(
          find.byKey(const ValueKey('module-group-validated')), findsNothing);

      data = _class([
        _modules[0],
        ClassModuleDetail(
          id: 2,
          name: 'Desarrollo espiritual',
          classId: 5,
          requirements: [
            _req(6, 'Campamento de liderazgo', RequirementStatus.validado,
                moduleId: 2),
            _req(7, 'Serie Encuentro I', RequirementStatus.pendiente,
                moduleId: 2),
          ],
        ),
      ]);
      final container = ProviderScope.containerOf(
          tester.element(find.byType(ClassModuleView)));
      container.invalidate(classWithProgressProvider);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(
          find.byKey(const ValueKey('module-group-validated')), findsOneWidget);
      expect(find.byKey(const ValueKey('module-group-toFix')), findsNothing);
    });
  });
}
