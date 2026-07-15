import 'dart:convert';
import 'dart:io';

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
import 'package:sacdia_app/features/evidence_folder/presentation/views/evidence_section_detail_view.dart';
import 'package:sacdia_app/features/evidence_folder/presentation/widgets/section_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> translations;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es');
    await EasyLocalization.ensureInitialized();
    translations = jsonDecode(
      await File('assets/translations/es.json').readAsString(),
    ) as Map<String, dynamic>;
    final evidenceFolderTranslations = Map<String, dynamic>.from(
      translations['evidence_folder'] as Map<String, dynamic>,
    )..addAll({
        'overview_label': '{name} · Avance',
        'search_hint': 'Buscar sección de evidencia…',
        'no_results_body': 'Intenta con otro nombre o descripción.',
      });
    translations = {
      ...translations,
      'evidence_folder': evidenceFolderTranslations,
    };
  });

  Future<void> pumpEvidenceFolder(
    WidgetTester tester, {
    EvidenceFolder? folder,
    double viewportWidth = 1200,
    double viewportHeight = 2000,
  }) async {
    tester.view.physicalSize = Size(viewportWidth, viewportHeight);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          evidenceFolderProvider('2').overrideWith(
            (ref) async => folder ?? _evidenceFolderFixture,
          ),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          fallbackLocale: const Locale('es'),
          assetLoader: _TestAssetLoader(translations),
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
      find.descendant(
        of: hero,
        matching: find.text('Carpeta 2026 · Avance'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hero, matching: find.text('62%')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hero, matching: find.text('31 / 50 pts')),
      findsOneWidget,
    );

    _expectStatusCount('evidence-status-validated', 4);
    _expectStatusCount('evidence-status-preapproved', 3);
    _expectStatusCount('evidence-status-submitted', 2);
    _expectStatusCount('evidence-status-rejected', 5);
    _expectStatusCount('evidence-status-pending', 1);
  });

  testWidgets('shows submitted folder state before the closed fallback',
      (tester) async {
    await pumpEvidenceFolder(tester, folder: _submittedFolderFixture);

    final hero = find.byKey(const ValueKey('evidence-folder-hero'));
    expect(
      find.descendant(of: hero, matching: find.text('Enviado')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hero, matching: find.text('Cerrada')),
      findsNothing,
    );
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

    expect(
      find.descendant(
        of: find.byType(SectionCard),
        matching: find.text('Camporee Readiness'),
      ),
      findsOneWidget,
    );
    expect(find.text('Administration Records'), findsNothing);
    expect(find.text('Community Service'), findsNothing);
    expect(find.text('Leadership Training'), findsNothing);
    expect(find.text('Health and Safety'), findsNothing);
  });

  testWidgets('groups compact section rows and shows their summary',
      (tester) async {
    await pumpEvidenceFolder(tester, viewportHeight: 5000);

    final groupedCard = find.byKey(const ValueKey('evidence-sections-card'));
    final pendingRow =
        find.byKey(const ValueKey('evidence-section-section-pending'));

    expect(groupedCard, findsOneWidget);
    for (final section in _evidenceFolderFixture.sections) {
      expect(
        find.descendant(
          of: groupedCard,
          matching: find.byKey(ValueKey('evidence-section-${section.id}')),
        ),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: groupedCard, matching: pendingRow),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: pendingRow,
        matching: find.text('Administration Records'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pendingRow, matching: find.text('Pendiente')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pendingRow, matching: find.text('0 / 10 pts')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pendingRow, matching: find.text('1 / 5 archivos')),
      findsOneWidget,
    );
  });

  testWidgets('opens section detail when a compact row is tapped',
      (tester) async {
    await pumpEvidenceFolder(tester);

    final pendingRow =
        find.byKey(const ValueKey('evidence-section-section-pending'));
    expect(pendingRow, findsOneWidget);

    await tester.tap(pendingRow);
    await tester.pumpAndSettle();

    expect(find.byType(EvidenceSectionDetailView), findsOneWidget);
  });

  testWidgets('shows send action for a submittable row in an open folder',
      (tester) async {
    await pumpEvidenceFolder(tester);

    final pendingRow =
        find.byKey(const ValueKey('evidence-section-section-pending'));
    final pendingSendAction = find.descendant(
      of: pendingRow,
      matching: find.byKey(
        const ValueKey('evidence-section-submit-section-pending'),
      ),
    );
    expect(pendingSendAction, findsOneWidget);
    expect(tester.getSize(pendingSendAction).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(pendingSendAction).height, greaterThanOrEqualTo(48));
  });

  testWidgets('hides send action when the folder is closed', (tester) async {
    await pumpEvidenceFolder(tester, folder: _closedFolderFixture);

    final closedPendingRow =
        find.byKey(const ValueKey('evidence-section-section-pending'));
    expect(closedPendingRow, findsOneWidget);
    expect(
      find.descendant(
        of: closedPendingRow,
        matching: find.text('Enviar a validación'),
      ),
      findsNothing,
    );
  });

  testWidgets('send action confirms without opening section detail',
      (tester) async {
    await pumpEvidenceFolder(tester);

    final pendingRow =
        find.byKey(const ValueKey('evidence-section-section-pending'));
    final sendAction = find.descendant(
      of: pendingRow,
      matching: find.byKey(
        const ValueKey('evidence-section-submit-section-pending'),
      ),
    );
    expect(sendAction, findsOneWidget);

    await tester.tap(sendAction);
    await tester.pumpAndSettle();

    expect(find.text('Enviar sección a validación'), findsOneWidget);
    expect(find.byType(EvidenceSectionDetailView), findsNothing);
  });

  testWidgets('compact rows honor large text without layout overflow',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );

    await pumpEvidenceFolder(
      tester,
      viewportWidth: 320,
      viewportHeight: 844,
    );

    final groupedCard = find.byKey(const ValueKey('evidence-sections-card'));
    await tester.scrollUntilVisible(
      groupedCard,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final pendingRow =
        find.byKey(const ValueKey('evidence-section-section-pending'));
    final pendingTitle = find.descendant(
      of: pendingRow,
      matching: find.text('Administration Records'),
    );
    final sendAction = find.descendant(
      of: pendingRow,
      matching: find.byKey(
        const ValueKey('evidence-section-submit-section-pending'),
      ),
    );

    expect(groupedCard, findsOneWidget);
    expect(pendingRow, findsOneWidget);
    expect(sendAction, findsOneWidget);
    expect(tester.getSize(sendAction).height, greaterThanOrEqualTo(48));
    expect(
      MediaQuery.textScalerOf(tester.element(pendingTitle)).scale(10),
      20,
    );
    expect(tester.widget<Text>(pendingTitle).textScaler, isNull);
    expect(tester.takeException(), isNull);
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

  testWidgets('clears the query and restores the complete section list',
      (tester) async {
    await pumpEvidenceFolder(tester, viewportHeight: 5000);

    final searchField = find.byKey(const ValueKey('evidence-section-search'));
    await tester.enterText(searchField, 'Administration Records');
    await tester.pumpAndSettle();
    expect(find.byType(SectionCard), findsOneWidget);

    final clearAction =
        find.byKey(const ValueKey('evidence-section-search-clear'));
    expect(clearAction, findsOneWidget);
    expect(tester.getSize(clearAction).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(clearAction).height, greaterThanOrEqualTo(48));

    await tester.tap(clearAction);
    await tester.pump();

    final field = tester.widget<TextField>(searchField);
    expect(field.controller?.text, isEmpty);
    expect(
      find.byType(SectionCard),
      findsNWidgets(_evidenceFolderFixture.sections.length),
    );
    await tester.pumpAndSettle();
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
    expect(
      find.text('Intenta con otro nombre o descripción.'),
      findsOneWidget,
    );
    for (final section in _evidenceFolderFixture.sections) {
      expect(find.text(section.name), findsNothing);
    }
  });
}

class _TestAssetLoader extends AssetLoader {
  final Map<String, dynamic> translations;

  const _TestAssetLoader(this.translations);

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async =>
      translations;
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

const _submittedFolderFixture = EvidenceFolder(
  folderId: 'folder-submitted',
  id: 'template-submitted',
  name: 'Carpeta enviada',
  isOpen: false,
  totalPoints: 50,
  totalPercentage: 100,
  totalEarnedPoints: 20,
  totalMaxPoints: 50,
  progressPercentage: 40,
  status: 'submitted',
  sections: [],
);

final _closedFolderFixture = EvidenceFolder(
  folderId: 'folder-closed',
  id: 'template-closed',
  name: 'Carpeta cerrada',
  isOpen: false,
  totalPoints: 100,
  totalPercentage: 100,
  totalEarnedPoints: 31,
  totalMaxPoints: 50,
  progressPercentage: 62,
  status: 'closed',
  sections: _evidenceFolderFixture.sections,
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
