import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/evidence_staging_manager.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_requirement.dart';
import 'package:sacdia_app/features/classes/presentation/views/requirement_detail_route_view.dart';

import '../grouped_class_test_support.dart';

void main() {
  setUpAll(initGroupedClassL10n);

  Future<void> pump(
    WidgetTester tester,
    List<ClassRequirement> requirements, {
    int id = 4,
    bool settle = true,
  }) {
    return pumpGroupedApp(
      tester,
      settle: settle,
      user: counselorUser,
      home: RequirementDetailRouteView(
        classId: 3,
        userId: 'x',
        requirementId: id,
        enrollmentId: 55,
        memberName: 'Ximena Delgado',
      ),
      overrides: [
        classProgressOverride(requirements),
      ],
    );
  }

  testWidgets('rejected: panel, local-field note and the action bar',
      (tester) async {
    await pump(tester, [
      requirement(4, 'Memorizar 5 versículos', RequirementStatus.rechazado,
          rejectionReason: 'La grabación no se escucha.'),
    ]);

    expect(
        find.byKey(const ValueKey('requirement-status-panel')), findsOneWidget);
    expect(find.text('Por corregir'), findsWidgets);
    for (final step in ['Archivos', 'Enviado', 'Campo local']) {
      expect(
        find.descendant(
          of: find.byType(SacStepPath),
          matching: find.text(step),
        ),
        findsOneWidget,
        reason: step,
      );
    }
    expect(find.text('Nota del campo local'), findsOneWidget);
    expect(find.text('La grabación no se escucha.'), findsOneWidget);
    expect(find.byType(EvidenceStagingActionBar), findsOneWidget);
    expect(find.text('Ximena Delgado · hasta 10 archivos'), findsOneWidget);
  });

  testWidgets('pending: action bar and the file counter', (tester) async {
    await pump(
        tester,
        [
          requirement(4, 'Proyecto', RequirementStatus.pendiente, files: 2),
        ],
        settle: false);
    expect(find.byType(EvidenceStagingActionBar), findsOneWidget);
    expect(find.text('2 de 10 archivos'), findsWidgets);
    expect(find.text('Nota del campo local'), findsNothing);
  });

  testWidgets('sent and validated: no action bar', (tester) async {
    await pump(tester, [
      requirement(4, 'Proyecto', RequirementStatus.enviado,
          submittedAt: DateTime(2026, 11, 5)),
    ]);
    expect(find.byType(EvidenceStagingActionBar), findsNothing);
    expect(find.textContaining('Enviado el 5 nov'), findsOneWidget);
  });

  testWidgets('a requirement that is not in the class says so', (tester) async {
    await pump(
      tester,
      [requirement(1, 'Otro', RequirementStatus.pendiente)],
      id: 99,
    );
    expect(find.byKey(const ValueKey('requirement-not-found')), findsOneWidget);
  });
}
