import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_file.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_folder.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_folder_template_availability.dart';
import 'package:sacdia_app/features/evidence_folder/domain/repositories/evidence_folder_repository.dart';
import 'package:sacdia_app/features/evidence_folder/domain/entities/evidence_section.dart';
import 'package:sacdia_app/features/evidence_folder/presentation/providers/evidence_folder_providers.dart';
import 'package:sacdia_app/features/evidence_folder/presentation/views/evidence_folder_view.dart';
import 'package:sacdia_app/features/evidence_folder/presentation/views/evidence_section_detail_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/riverpod_test_support.dart';

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
    Future<EvidenceFolder?> Function(Ref ref)? loadFolder,
    double viewportWidth = 1200,
    double viewportHeight = 2000,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = Size(viewportWidth, viewportHeight);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          evidenceFolderProvider('2').overrideWith(
            loadFolder ?? (ref) async => folder ?? _evidenceFolderFixture,
          ),
          ...overrides,
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

  testWidgets('open folder: one summary with ready sections and a legend',
      (tester) async {
    await pumpEvidenceFolder(tester);

    final summary = find.byKey(const ValueKey('evidence-folder-summary'));
    expect(summary, findsOneWidget);
    // 4 submitted/preapproved... ready = 2 + 3 + 4 = 9 of 15.
    expect(
      find.descendant(
        of: summary,
        matching: find.textContaining('9 de 15', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summary,
        matching: find.textContaining('faltan 6', findRichText: true),
      ),
      findsOneWidget,
    );
    for (final label in [
      '4 validadas',
      '5 en revisión',
      '5 por corregir',
      '1 sin enviar',
    ]) {
      expect(
          find.descendant(
              of: summary,
              matching: find.textContaining(label, findRichText: true)),
          findsOneWidget);
    }
    expect(find.descendant(of: summary, matching: find.text('31 de 50')),
        findsOneWidget);
    // The bar paints: every segment is as tall as the track.
    final bar = find.byKey(const ValueKey('evidence-folder-status-bar'));
    final segments =
        find.descendant(of: bar, matching: find.byType(ColoredBox));
    expect(segments, findsNWidgets(4));
    for (final segment in segments.evaluate()) {
      expect(tester.getSize(find.byWidget(segment.widget)).height, 8);
    }
    // No search, no counters with zeros.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('reloads the folder when the user pulls to refresh',
      (tester) async {
    var requests = 0;
    await pumpEvidenceFolder(
      tester,
      loadFolder: (ref) async {
        requests++;
        return _evidenceFolderFixture;
      },
    );
    expect(requests, 1);

    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refresh;

    expect(requests, 2);
  });

  testWidgets('sent folder says it is waiting, not closed', (tester) async {
    await pumpEvidenceFolder(tester, folder: _submittedFolderFixture);

    final summary = find.byKey(const ValueKey('evidence-folder-summary'));
    expect(find.descendant(of: summary, matching: find.text('Carpeta enviada')),
        findsOneWidget);
    expect(find.text('Carpeta cerrada'), findsNothing);
  });

  testWidgets('closed folder says so once', (tester) async {
    await pumpEvidenceFolder(tester, folder: _closedFolderFixture);

    expect(find.text('Carpeta cerrada'), findsOneWidget);
  });

  testWidgets('evaluated folder shows a single result and one plain list',
      (tester) async {
    await pumpEvidenceFolder(tester, folder: _evaluatedFolderFixture);

    final result = find.byKey(const ValueKey('evidence-folder-summary-result'));
    expect(result, findsOneWidget);
    final resultText = tester
        .widget<RichText>(
            find.descendant(of: result, matching: find.byType(RichText)).first)
        .text
        .toPlainText();
    expect(resultText, contains('3,700'));
    expect(resultText, contains('de 4,000 pts'));
    expect(find.text('93% · 2 de 2 secciones validadas'), findsOneWidget);
    expect(find.byKey(const ValueKey('evidence-group-all')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('evidence-folder-status-bar')), findsNothing);
  });

  testWidgets('groups sections by what the club has to do', (tester) async {
    await pumpEvidenceFolder(tester, viewportHeight: 5000);

    final attention = find.byKey(const ValueKey('evidence-group-attention'));
    final review = find.byKey(const ValueKey('evidence-group-review'));
    final validated = find.byKey(const ValueKey('evidence-group-validated'));
    expect(attention, findsOneWidget);
    expect(review, findsOneWidget);
    expect(validated, findsOneWidget);

    expect(
      find.descendant(
        of: attention,
        matching:
            find.byKey(const ValueKey('evidence-section-section-pending')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: attention,
        matching:
            find.byKey(const ValueKey('evidence-section-section-rejected-1')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: validated,
        matching:
            find.byKey(const ValueKey('evidence-section-section-validated-1')),
      ),
      findsOneWidget,
    );
    // Rejected first inside «Por atender».
    final rejectedY = tester
        .getTopLeft(
            find.byKey(const ValueKey('evidence-section-section-rejected-1')))
        .dy;
    final pendingY = tester
        .getTopLeft(
            find.byKey(const ValueKey('evidence-section-section-pending')))
        .dy;
    expect(rejectedY, lessThan(pendingY));
  });

  testWidgets('a row says only what matters in its state', (tester) async {
    await pumpEvidenceFolder(tester, viewportHeight: 5000);

    final pendingRow =
        find.byKey(const ValueKey('evidence-section-section-pending'));
    expect(
      find.descendant(
          of: pendingRow, matching: find.text('1 de 5 archivos · 10 pts')),
      findsOneWidget,
    );
    final rejectedRow =
        find.byKey(const ValueKey('evidence-section-section-rejected-1'));
    expect(
      find.descendant(
          of: rejectedRow, matching: find.text('«Falta la foto del grupo»')),
      findsOneWidget,
    );
    final validatedRow =
        find.byKey(const ValueKey('evidence-section-section-validated-1'));
    expect(
      find.descendant(of: validatedRow, matching: find.text('10 / 10 pts')),
      findsOneWidget,
    );
  });

  testWidgets('opens section detail when a row is tapped', (tester) async {
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

    expect(find.byKey(const ValueKey('evidence-section-section-pending')),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey('evidence-section-submit-section-pending')),
      findsNothing,
    );
  });

  testWidgets('send action confirms without opening section detail',
      (tester) async {
    await pumpEvidenceFolder(tester);

    final sendAction = find.byKey(
      const ValueKey('evidence-section-submit-section-pending'),
    );
    expect(sendAction, findsOneWidget);

    await tester.tap(sendAction);
    await tester.pumpAndSettle();

    expect(find.text('Enviar sección a validación'), findsOneWidget);
    expect(find.byType(EvidenceSectionDetailView), findsNothing);
  });

  testWidgets('rows honor large text without layout overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );

    await pumpEvidenceFolder(
      tester,
      viewportWidth: 320,
      viewportHeight: 844,
    );

    final pendingRow =
        find.byKey(const ValueKey('evidence-section-section-pending'));
    await tester.scrollUntilVisible(
      pendingRow,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final sendAction = find.descendant(
      of: pendingRow,
      matching: find.byKey(
        const ValueKey('evidence-section-submit-section-pending'),
      ),
    );
    expect(sendAction, findsOneWidget);
    expect(tester.getSize(sendAction).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  group('no folder yet', () {
    Future<void> pumpNoFolder(
      WidgetTester tester, {
      required _FakeEvidenceFolderRepository repository,
    }) {
      return pumpEvidenceFolder(
        tester,
        loadFolder: (ref) async => null,
        overrides: [
          authNotifierProvider.overrideWith(() => _TestAuthNotifier(_editor)),
          evidenceFolderRepositoryProvider.overrideWithValue(repository),
        ],
      );
    }

    testWidgets('hides create action when no template is published',
        (tester) async {
      await pumpNoFolder(
        tester,
        repository: _FakeEvidenceFolderRepository(
          availability: const EvidenceFolderTemplateAvailability(
            isAvailable: false,
            clubTypeName: 'Guías Mayores',
            yearLabel: '2025-2026',
          ),
        ),
      );

      expect(find.text('Crear carpeta'), findsNothing);
      expect(
        find.textContaining('Ya hay una plantilla publicada'),
        findsNothing,
      );
      expect(
        find.text(
          'Aún no hay una plantilla publicada para Guías Mayores (2025-2026). '
          'Cuando tu campo local o unión la publique, podrás crear la carpeta aquí.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('offers create action when a template is published',
        (tester) async {
      await pumpNoFolder(
        tester,
        repository: _FakeEvidenceFolderRepository(
          availability:
              const EvidenceFolderTemplateAvailability(isAvailable: true),
        ),
      );

      expect(find.text('Crear carpeta'), findsOneWidget);
      expect(
        find.textContaining('Ya hay una plantilla publicada'),
        findsOneWidget,
      );
    });

    testWidgets('shows a create failure once, without a duplicate snackbar',
        (tester) async {
      const message = 'No se pudo crear la carpeta.';
      await pumpNoFolder(
        tester,
        repository: _FakeEvidenceFolderRepository(
          availability:
              const EvidenceFolderTemplateAvailability(isAvailable: true),
          createFailure: const ServerFailure(message: message),
        ),
      );

      await tester.tap(find.text('Crear carpeta'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}

class _TestAuthNotifier extends AuthNotifier {
  final UserEntity? user;

  _TestAuthNotifier(this.user);

  @override
  Future<UserEntity?> build() async => user;
}

const _editor = UserEntity(
  id: 'director-user',
  email: 'director@example.com',
  authorization: AuthorizationSnapshot(
    effectivePermissions: ['evidence_folders:read', 'evidence_folders:update'],
  ),
);

class _FakeEvidenceFolderRepository implements EvidenceFolderRepository {
  final EvidenceFolderTemplateAvailability availability;
  final Failure? createFailure;

  _FakeEvidenceFolderRepository({
    required this.availability,
    this.createFailure,
  });

  @override
  Future<Either<Failure, EvidenceFolderTemplateAvailability>>
      getTemplateAvailability(String clubSectionId) async =>
          Right(availability);

  @override
  Future<Either<Failure, EvidenceFolder>> createEvidenceFolder(
    String clubSectionId,
  ) async =>
      Left(createFailure ?? const ServerFailure(message: 'unexpected'));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _TestAssetLoader extends AssetLoader {
  final Map<String, dynamic> translations;

  const _TestAssetLoader(this.translations);

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async =>
      translations;
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

final _evaluatedFolderFixture = EvidenceFolder(
  folderId: 'folder-evaluated',
  id: 'template-evaluated',
  name: 'Carpeta evaluada',
  isOpen: false,
  totalPoints: 4000,
  totalPercentage: 100,
  totalEarnedPoints: 3700,
  totalMaxPoints: 4000,
  progressPercentage: 92.5,
  evaluatedAt: DateTime.utc(2026, 7, 30),
  status: 'evaluated',
  sections: const [
    EvidenceSection(
      id: 'section-a',
      name: 'Servicio a la comunidad',
      pointValue: 2000,
      percentage: 50,
      status: EvidenceSectionStatus.validated,
      earnedPoints: 2000,
    ),
    EvidenceSection(
      id: 'section-b',
      name: 'Salidas recreativas',
      pointValue: 2000,
      percentage: 50,
      status: EvidenceSectionStatus.validated,
      earnedPoints: 1700,
    ),
  ],
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
      evaluationNotes: status == EvidenceSectionStatus.rejected && index == 0
          ? 'Falta la foto del grupo'
          : null,
    ),
  );
}
