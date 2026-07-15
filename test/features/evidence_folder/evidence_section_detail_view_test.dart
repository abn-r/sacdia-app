import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_section.dart';
import 'package:sacdia_app/features/evidence_folder/presentation/views/evidence_section_detail_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pins evidence section actions to the Scaffold bottom bar',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
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

  testWidgets('omits weight and preserves a neutral title hierarchy',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
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

    expect(find.text('evidence_folder.weight_label'), findsNothing);
    expect(find.text('25.0%'), findsNothing);

    final appBarTitle = tester.widget<Text>(
      find.text('evidence_folder.section_title'),
    );
    final sectionName = tester.widget<Text>(find.text('Administración'));

    expect(appBarTitle.style?.color, isNot(AppColors.primary));
    expect(
      sectionName.style?.fontSize,
      lessThan(appBarTitle.style?.fontSize ?? double.infinity),
    );
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
