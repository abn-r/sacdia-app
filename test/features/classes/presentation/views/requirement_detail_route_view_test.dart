import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/evidence_staging_manager.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
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

  testWidgets('rejected: card panel without step bar, note and "Reenviar"',
      (tester) async {
    await pump(tester, [
      requirement(4, 'Memorizar 5 versículos', RequirementStatus.rechazado,
          rejectionReason: 'La grabación no se escucha.',
          rejectedAt: DateTime(2026, 11, 15)),
    ]);

    expect(find.byType(SacStatePanel), findsOneWidget);
    expect(find.byType(SacStepPath), findsNothing);
    expect(find.text('Por corregir'), findsWidgets);
    expect(find.text('Devuelto el 15 nov · corrige y vuelve a enviar'),
        findsOneWidget);
    expect(find.text('Paso 1 de 3 · Ver todos los estados'), findsOneWidget);
    expect(find.text('NOTA DEL CAMPO LOCAL'), findsOneWidget);
    expect(find.text('«La grabación no se escucha.»'), findsOneWidget);
    expect(find.byType(EvidenceStagingActionBar), findsOneWidget);
    expect(find.text('Reenviar'), findsOneWidget);
    expect(find.text('Ximena Delgado · hasta 10 archivos'), findsOneWidget);
  });

  testWidgets('pending: description, hint, add tile and "Enviar 2 archivos"',
      (tester) async {
    await pump(
        tester,
        [
          requirement(4, 'Proyecto', RequirementStatus.pendiente,
              files: 2, description: 'Leer el libro y escribir una reacción.'),
        ],
        settle: false);
    expect(find.byType(EvidenceStagingActionBar), findsOneWidget);
    expect(find.text('Leer el libro y escribir una reacción.'), findsOneWidget);
    expect(find.text('Imágenes o PDF · hasta 10 archivos de 10 MB'),
        findsOneWidget);
    expect(find.text('ARCHIVOS'), findsOneWidget);
    expect(find.text('2 de 10'), findsOneWidget);
    expect(find.byKey(const ValueKey('evidence-add-tile')), findsOneWidget);
    expect(find.text('Enviar 2 archivos'), findsOneWidget);
    // The old "Imagen" / "PDF" outline buttons are gone.
    expect(find.text('Imagen'), findsNothing);
    expect(find.text('PDF'), findsNothing);
    expect(find.text('NOTA DEL CAMPO LOCAL'), findsNothing);
    // With files in a modifiable requirement the remove button is there.
    expect(
      find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Quitar archivo'),
      findsNWidgets(2),
    );
  });

  testWidgets('the add tile opens the camera / gallery / PDF sheet',
      (tester) async {
    await pump(tester, [
      requirement(4, 'Proyecto', RequirementStatus.pendiente),
    ]);

    await tester.tap(find.byKey(const ValueKey('evidence-add-tile')));
    await tester.pumpAndSettle();

    expect(find.text('Agregar evidencia'), findsOneWidget);
    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Elegir de la galería'), findsOneWidget);
    expect(find.text('Elegir PDF'), findsOneWidget);
  });

  testWidgets('with nothing staged the single action is disabled',
      (tester) async {
    await pump(tester, [
      requirement(4, 'Proyecto', RequirementStatus.pendiente),
    ]);

    expect(find.text('Enviar archivos'), findsOneWidget);
    final submit = tester.widget<SacButton>(
      find.byKey(const ValueKey('evidence-submit')),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets('tapping the panel lists every state with the detour apart',
      (tester) async {
    await pump(
        tester,
        [
          requirement(4, 'Proyecto', RequirementStatus.enviado,
              submittedAt: DateTime(2026, 11, 5), files: 4),
        ],
        settle: false);

    await tester.tap(find.byKey(const ValueKey('requirement-status-panel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Estados del requisito'), findsOneWidget);
    final sheet = find.byType(SacStatesSheet);
    for (final title in ['Sin enviar', 'Enviado', 'Validado', 'Por corregir']) {
      expect(find.descendant(of: sheet, matching: find.text(title)),
          findsOneWidget,
          reason: title);
    }
    expect(find.text('Subiste 4 archivos'), findsOneWidget);
    expect(find.text('5 nov · en revisión del campo local'), findsOneWidget);
    expect(find.byKey(const ValueKey('states-sheet-detour')), findsOneWidget);
  });

  testWidgets('the top bar menu opens the same states sheet', (tester) async {
    await pump(tester, [
      requirement(4, 'Proyecto', RequirementStatus.pendiente),
    ]);

    await tester.tap(find.byTooltip('Estados del requisito'));
    await tester.pumpAndSettle();

    expect(find.byType(SacStatesSheet), findsOneWidget);
  });

  testWidgets('sent: read-only, no add tile, no footer', (tester) async {
    await pump(
        tester,
        [
          requirement(4, 'Proyecto', RequirementStatus.enviado,
              submittedAt: DateTime(2026, 11, 5), files: 3),
        ],
        settle: false);
    expect(find.byType(EvidenceStagingActionBar), findsNothing);
    expect(find.byKey(const ValueKey('evidence-add-tile')), findsNothing);
    expect(
      find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Quitar archivo'),
      findsNothing,
    );
    expect(
        find.text('Imágenes o PDF · hasta 10 archivos de 10 MB'), findsNothing);
    expect(find.text('Enviado'), findsWidgets);
    expect(find.textContaining('Enviado el 5 nov'), findsOneWidget);
    expect(find.text('Paso 2 de 3 · Ver todos los estados'), findsOneWidget);
  });

  testWidgets('validated: read-only with the validation date', (tester) async {
    await pump(
        tester,
        [
          requirement(4, 'Proyecto', RequirementStatus.validado,
              validatedAt: DateTime(2026, 11, 9), files: 1),
        ],
        settle: false);
    expect(find.byType(EvidenceStagingActionBar), findsNothing);
    expect(find.byKey(const ValueKey('evidence-add-tile')), findsNothing);
    expect(find.text('Validado el 9 nov'), findsOneWidget);
    expect(find.text('Paso 3 de 3 · Ver todos los estados'), findsOneWidget);
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
