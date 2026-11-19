import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/evidence_staging_manager.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_requirement.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/views/requirement_detail_view.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';

import '../../../../support/riverpod_test_support.dart';
import '../grouped_class_test_support.dart';

void main() {
  setUpAll(initGroupedClassL10n);

  Future<Navigated> pump(
    WidgetTester tester, {
    required ClassRequirement requirement,
    String? targetUserId,
  }) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final navigated = Navigated();
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (_, __) => RequirementDetailView(
            requirement: requirement,
            classId: 3,
            enrollmentId: 55,
            targetUserId: targetUserId,
          ),
        ),
        GoRoute(
          path: '/honor/:honorId',
          builder: (_, state) {
            navigated.locations.add(state.uri);
            return Scaffold(body: Text('STUB ${state.uri.path}'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          classWithProgressProvider(
            ClassProgressQuery(
              classId: 3,
              enrollmentId: 55,
              targetUserId: targetUserId,
            ),
          ).overrideWith((ref) async => classWithRequirements([requirement])),
          userHonorsProvider.overrideWith((ref) async => []),
          userHonorProgressProvider(7).overrideWith(
            (ref) async => const [
              UserHonorRequirementProgress(
                requirementId: 1,
                requirementNumber: 1,
                text: 'Uno',
                completed: true,
              ),
              UserHonorRequirementProgress(
                requirementId: 2,
                requirementNumber: 2,
                text: 'Dos',
              ),
            ],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return navigated;
  }

  const honorRequirement = ClassRequirement(
    id: 4,
    name: 'Especialidad: Amarres',
    moduleId: 1,
    status: RequirementStatus.pendiente,
    linkedHonorId: 7,
    linkedHonorName: 'Amarres',
    linkedHonorCompleted: false,
  );

  testWidgets('shows the honor instead of the file grid and goes to it',
      (tester) async {
    final navigated = await pump(tester, requirement: honorRequirement);

    expect(find.byType(SacStatePanel), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Se valida solo cuando completes la especialidad.'),
        findsOneWidget);
    expect(find.text('Especialidad requerida'), findsOneWidget);

    expect(find.byKey(const ValueKey('linked-honor-card')), findsOneWidget);
    expect(find.text('Amarres'), findsOneWidget);
    expect(find.text('1 de 2 requisitos'), findsOneWidget);

    expect(find.byType(EvidenceStagingManager), findsNothing);
    expect(find.byType(EvidenceStagingActionBar), findsNothing);
    expect(find.byKey(const ValueKey('evidence-add-tile')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('requirement-go-honor')));
    await tester.pumpAndSettle();
    expect(navigated.last.path, '/honor/7');
  });

  testWidgets('a completed honor says "Completada"', (tester) async {
    await pump(
      tester,
      requirement: const ClassRequirement(
        id: 4,
        name: 'Especialidad: Amarres',
        moduleId: 1,
        status: RequirementStatus.validado,
        linkedHonorId: 7,
        linkedHonorName: 'Amarres',
        linkedHonorCompleted: true,
      ),
    );

    expect(find.text('Completada'), findsOneWidget);
    expect(find.text('Ya cuenta para tu avance.'), findsOneWidget);
  });

  testWidgets('a coach sees the honor without the footer or own progress',
      (tester) async {
    await pump(tester, requirement: honorRequirement, targetUserId: 'x');

    expect(find.byKey(const ValueKey('linked-honor-card')), findsOneWidget);
    expect(find.text('1 de 2 requisitos'), findsNothing);
    expect(find.byKey(const ValueKey('requirement-go-honor')), findsNothing);
  });
}
