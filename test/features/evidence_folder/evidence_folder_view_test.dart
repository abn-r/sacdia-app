import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_file.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_folder.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_section.dart';
import 'package:sacdia_app/features/evidence_folder/presentation/providers/evidence_folder_providers.dart';
import 'package:sacdia_app/features/evidence_folder/presentation/views/evidence_folder_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es');
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpEvidenceFolder(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          evidenceFolderProvider('2').overrideWith(
            (ref) async => _evidenceFolderFixture,
          ),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          fallbackLocale: const Locale('es'),
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: const EvidenceFolderView(clubSectionId: '2'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('shows the folder hero and one count for every section status',
      (tester) async {
    await pumpEvidenceFolder(tester);

    final hero = find.byKey(const ValueKey('evidence-folder-hero'));
    expect(hero, findsOneWidget);
    expect(
      find.descendant(of: hero, matching: find.text('Carpeta 2026')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hero, matching: find.text('62%')),
      findsOneWidget,
    );

    _expectStatusCount('evidence-status-validated', 4);
    _expectStatusCount('evidence-status-preapproved', 3);
    _expectStatusCount('evidence-status-submitted', 2);
    _expectStatusCount('evidence-status-rejected', 5);
    _expectStatusCount('evidence-status-pending', 1);
  });

  testWidgets('filters sections by name', (tester) async {
    await pumpEvidenceFolder(tester);

    final searchField = find.byKey(const ValueKey('evidence-section-search'));
    expect(searchField, findsOneWidget);
    await tester.enterText(
      searchField,
      'Camporee Readiness',
    );
    await tester.pumpAndSettle();

    expect(find.text('Camporee Readiness'), findsOneWidget);
    expect(find.text('Administration Records'), findsNothing);
    expect(find.text('Community Service'), findsNothing);
    expect(find.text('Leadership Training'), findsNothing);
    expect(find.text('Health and Safety'), findsNothing);
  });

  testWidgets('filters sections by description without matching case',
      (tester) async {
    await pumpEvidenceFolder(tester);

    final searchField = find.byKey(const ValueKey('evidence-section-search'));
    expect(searchField, findsOneWidget);
    await tester.enterText(
      searchField,
      'mission archive',
    );
    await tester.pumpAndSettle();

    expect(find.text('Community Service'), findsOneWidget);
    expect(find.text('Administration Records'), findsNothing);
    expect(find.text('Camporee Readiness'), findsNothing);
    expect(find.text('Leadership Training'), findsNothing);
    expect(find.text('Health and Safety'), findsNothing);
  });

  testWidgets('shows a no-results state when no section matches',
      (tester) async {
    await pumpEvidenceFolder(tester);

    final searchField = find.byKey(const ValueKey('evidence-section-search'));
    expect(searchField, findsOneWidget);
    await tester.enterText(
      searchField,
      'missing section',
    );
    await tester.pumpAndSettle();

    expect(find.text('No se encontraron resultados'), findsOneWidget);
    for (final section in _evidenceFolderFixture.sections) {
      expect(find.text(section.name), findsNothing);
    }
  });
}

void _expectStatusCount(String key, int count) {
  final statusPill = find.byKey(ValueKey(key));
  expect(statusPill, findsOneWidget);
  expect(
    find.descendant(of: statusPill, matching: find.text('$count')),
    findsOneWidget,
  );
}

final _evidenceFolderFixture = EvidenceFolder(
  folderId: 'folder-1',
  id: 'template-1',
  name: 'Carpeta 2026',
  description: 'Evidencias anuales del club',
  isOpen: true,
  totalPoints: 100,
  totalPercentage: 100,
  totalEarnedPoints: 31,
  totalMaxPoints: 50,
  progressPercentage: 62,
  status: 'open',
  sections: [
    EvidenceSection(
      id: 'section-pending',
      name: 'Administration Records',
      description: 'Secretary documents for the annual record',
      pointValue: 10,
      percentage: 20,
      maxFiles: 5,
      status: EvidenceSectionStatus.pending,
      files: [
        EvidenceFile(
          id: 'file-1',
          url: 'https://example.com/evidence.pdf',
          fileName: 'minutes.pdf',
          type: EvidenceFileType.pdf,
          uploadedByName: 'Ana Test',
          uploadedAt: DateTime.utc(2026, 1, 15),
        ),
      ],
    ),
    ..._sectionsForStatus(
      status: EvidenceSectionStatus.submitted,
      count: 2,
      idPrefix: 'submitted',
      firstName: 'Community Service',
      firstDescription: 'Unique MISSION Archive for neighborhood outreach',
    ),
    ..._sectionsForStatus(
      status: EvidenceSectionStatus.preapprovedLf,
      count: 3,
      idPrefix: 'preapproved',
      firstName: 'Camporee Readiness',
      firstDescription: 'Equipment checklist verified by the local field',
    ),
    ..._sectionsForStatus(
      status: EvidenceSectionStatus.validated,
      count: 4,
      idPrefix: 'validated',
      firstName: 'Leadership Training',
      firstDescription: 'Mentor development attendance records',
    ),
    ..._sectionsForStatus(
      status: EvidenceSectionStatus.rejected,
      count: 5,
      idPrefix: 'rejected',
      firstName: 'Health and Safety',
      firstDescription: 'First-aid procedure awaiting corrections',
    ),
  ],
);

List<EvidenceSection> _sectionsForStatus({
  required EvidenceSectionStatus status,
  required int count,
  required String idPrefix,
  required String firstName,
  required String firstDescription,
}) {
  return List.generate(
    count,
    (index) => EvidenceSection(
      id: 'section-$idPrefix-${index + 1}',
      name: index == 0 ? firstName : '$firstName ${index + 1}',
      description:
          index == 0 ? firstDescription : '$firstDescription ${index + 1}',
      pointValue: 10,
      percentage: 20,
      status: status,
      earnedPoints: status == EvidenceSectionStatus.validated ? 10 : 0,
    ),
  );
}
