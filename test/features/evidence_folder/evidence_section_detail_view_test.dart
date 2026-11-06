import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_section.dart';
import 'package:sacdia_app/features/evidence_folder/presentation/views/evidence_section_detail_view.dart';
import '../../support/riverpod_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expect(find.text('PDF'), findsOneWidget);
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

    // One status panel with the step path; no status badge in the top bar.
    expect(find.byKey(const ValueKey('evidence-section-status-panel')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('evidence-section-step-path')),
        findsOneWidget);
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

  testWidgets('validated by the local field alone: no union step',
      (tester) async {
    await pumpDetail(tester, validated);

    expect(find.text('evidence_folder.panel.step_local_field'), findsOneWidget);
    expect(find.text('evidence_folder.panel.step_union'), findsNothing);
  });

  testWidgets('a folder that requires the union shows its step',
      (tester) async {
    await pumpDetail(tester, validated, requiresUnion: true);

    expect(find.text('evidence_folder.panel.step_union'), findsOneWidget);
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
