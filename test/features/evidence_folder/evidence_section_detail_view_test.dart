import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/evidence_staging_manager.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_section.dart';
import 'package:sacdia_app/features/evidence_folder/presentation/views/evidence_section_detail_view.dart';
import '../../support/l10n_test_support.dart';
import '../../support/riverpod_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadSpanishTranslations);

  testWidgets('pins evidence section actions to the Scaffold bottom bar',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testProviderScope(
        child: MaterialApp(
          home: EvidenceSectionDetailView(
            section: _pendingSection(),
            folderIsOpen: true,
            clubSectionId: '2',
          ),
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.bottomNavigationBar, isNotNull);
    // One primary action; the "Imagen" / "PDF" buttons are gone.
    expect(find.byType(EvidenceStagingActionBar), findsOneWidget);
    expect(find.text('Enviar archivos'), findsOneWidget);
    expect(find.text('PDF'), findsNothing);
    expect(find.byKey(const ValueKey('evidence-add-tile')), findsOneWidget);
    expect(find.text('ARCHIVOS'), findsOneWidget);
    expect(find.text('0 de 5'), findsOneWidget);
  });

  testWidgets('titles the screen with the section name and one status panel',
      (tester) async {
    await tester.pumpWidget(
      testProviderScope(
        child: MaterialApp(
          home: EvidenceSectionDetailView(
            section: _pendingSection(),
            folderIsOpen: true,
            clubSectionId: '2',
          ),
        ),
      ),
    );
    await tester.pump();

    // Section name is the title; no generic «Sección» label above it.
    expect(find.text('Administración'), findsOneWidget);
    expect(find.text('evidence_folder.section_title'), findsNothing);
    expect(find.text('evidence_folder.section_detail_label'), findsNothing);
    expect(find.text('evidence_folder.weight_label'), findsNothing);

    // One card panel with the current state and no step bar.
    expect(find.byKey(const ValueKey('evidence-section-status-panel')),
        findsOneWidget);
    expect(find.byType(SacStatePanel), findsOneWidget);
    expect(find.byType(SacStepPath), findsNothing);
    expect(find.text('Sin enviar'), findsOneWidget);
    expect(find.text('Paso 1 de 3 · Ver todos los estados'), findsOneWidget);
  });
  Future<void> pumpDetail(
    WidgetTester tester,
    EvidenceSection section, {
    bool requiresUnion = false,
  }) async {
    await tester.pumpWidget(
      testProviderScope(
        child: MaterialApp(
          home: EvidenceSectionDetailView(
            section: section,
            folderIsOpen: false,
            clubSectionId: '2',
            requiresUnion: requiresUnion,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  const validated = EvidenceSection(
    id: 'section-2',
    name: 'Servicio a la comunidad',
    pointValue: 800,
    percentage: 20,
    status: EvidenceSectionStatus.validated,
    earnedPoints: 800,
  );

  Future<void> openStates(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey('evidence-section-status-panel')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('validated by the local field alone: three states, no union',
      (tester) async {
    await pumpDetail(tester, validated);

    expect(find.text('Paso 3 de 3 · 800 / 800 pts'), findsOneWidget);
    await openStates(tester);

    expect(find.byType(SacStatesSheet), findsOneWidget);
    expect(find.text('Aprobada por el campo local'), findsNothing);
    for (final title in ['Sin enviar', 'Enviada', 'Validada', 'Por corregir']) {
      expect(
        find.descendant(
            of: find.byType(SacStatesSheet), matching: find.text(title)),
        findsOneWidget,
        reason: title,
      );
    }
    // Read-only: no add tile, no footer.
    expect(find.byKey(const ValueKey('evidence-add-tile')), findsNothing);
    expect(find.byType(EvidenceStagingActionBar), findsNothing);
  });

  testWidgets('a folder that requires the union adds its step to the sheet',
      (tester) async {
    await pumpDetail(tester, validated, requiresUnion: true);

    expect(find.text('Paso 4 de 4 · 800 / 800 pts'), findsOneWidget);
    await openStates(tester);

    expect(find.text('Aprobada por el campo local'), findsOneWidget);
  });

  testWidgets('rejected: note quoted and the detour is the current state',
      (tester) async {
    await pumpDetail(
      tester,
      const EvidenceSection(
        id: 'section-3',
        name: 'Finanzas',
        pointValue: 10,
        percentage: 20,
        maxFiles: 5,
        status: EvidenceSectionStatus.rejected,
        evaluationNotes: 'Falta el recibo.',
      ),
    );

    expect(find.text('Por corregir'), findsWidgets);
    expect(find.text('NOTA DEL CAMPO LOCAL'), findsOneWidget);
    expect(find.text('«Falta el recibo.»'), findsOneWidget);
    await openStates(tester);
    expect(find.byKey(const ValueKey('states-sheet-detour')), findsOneWidget);
  });
}

EvidenceSection _pendingSection() {
  return const EvidenceSection(
    id: 'section-1',
    name: 'Administración',
    description: 'Documentos administrativos',
    pointValue: 10,
    percentage: 25,
    maxFiles: 5,
    status: EvidenceSectionStatus.pending,
  );
}
