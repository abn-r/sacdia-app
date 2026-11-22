import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_batch_list.dart';
import 'package:sacdia_app/features/certificate_import/presentation/providers/certificate_import_providers.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_upload_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/import_recent_batches.dart';

import '../../support/test_app.dart';
import '../../../../support/riverpod_test_support.dart';

CertificateImportBatchSummary _batch(
  String id,
  String status, {
  int items = 3,
  int rejected = 0,
  DateTime? modifiedAt,
}) =>
    CertificateImportBatchSummary(
      id: id,
      status: status,
      modifiedAt: modifiedAt ?? DateTime(2026, 10, 12, 12),
      itemCount: items,
      rejectedCount: rejected,
    );

CertificateImportBatchList _list(List<CertificateImportBatchSummary> items) =>
    CertificateImportBatchList(
      items: items,
      total: items.length,
      page: 1,
      limit: 10,
    );

/// Hosts [home] at `/` with stub review and status routes that print where
/// the member landed.
Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required Future<CertificateImportBatchList> Function() batches,
}) async {
  phoneSurface(tester, height: 1400);
  await tester.pumpWidget(testProviderScope(
    overrides: [
      certificateImportBatchListProvider.overrideWith((ref, args) => batches()),
    ],
    child: EasyLocalization(
      supportedLocales: const [Locale('es')],
      path: 'assets/translations',
      assetLoader: const FileAssetLoader(),
      fallbackLocale: const Locale('es'),
      startLocale: const Locale('es'),
      child: Builder(
        builder: (context) => MaterialApp.router(
          theme: AppTheme.lightTheme,
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          routerConfig: GoRouter(routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => Scaffold(body: ListView(children: [home])),
            ),
            GoRoute(
              path: RouteNames.certificateImportReview,
              builder: (_, state) => Scaffold(
                body: Text('REVIEW ${state.pathParameters['batchId']}'),
              ),
            ),
            GoRoute(
              path: RouteNames.certificateImportStatus,
              builder: (_, state) => Scaffold(
                body: Text('STATUS ${state.pathParameters['batchId']}'),
              ),
            ),
          ]),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestLocalization);

  group('importBatchStageOf', () {
    test('maps every API batch status', () {
      expect(importBatchStageOf('DRAFT'), ImportBatchStage.draft);
      expect(importBatchStageOf('READY_TO_SUBMIT'), ImportBatchStage.draft);
      expect(importBatchStageOf('SUBMITTED'), ImportBatchStage.inReview);
      expect(importBatchStageOf('REJECTED'), ImportBatchStage.corrections);
      expect(
          importBatchStageOf('NEEDS_CORRECTION'), ImportBatchStage.corrections);
      expect(
          importBatchStageOf('PARTIALLY_APPROVED'), ImportBatchStage.partial);
      expect(importBatchStageOf('APPROVED'), ImportBatchStage.approved);
      expect(importBatchStageOf('SOMETHING_NEW'), ImportBatchStage.inReview);
    });
  });

  group('importSummaryStageOf', () {
    test('a sent batch with a rejected row needs a correction', () {
      expect(importSummaryStageOf(_batch('a', 'SUBMITTED', rejected: 1)),
          ImportBatchStage.corrections);
      expect(
          importSummaryStageOf(_batch('b', 'PARTIALLY_APPROVED', rejected: 2)),
          ImportBatchStage.corrections);
    });

    test('without rejected rows it follows the batch status', () {
      expect(importSummaryStageOf(_batch('a', 'SUBMITTED')),
          ImportBatchStage.inReview);
      expect(importSummaryStageOf(_batch('b', 'PARTIALLY_APPROVED')),
          ImportBatchStage.partial);
      expect(importSummaryStageOf(_batch('c', 'DRAFT', rejected: 1)),
          ImportBatchStage.draft);
      expect(importSummaryStageOf(_batch('d', 'APPROVED', rejected: 1)),
          ImportBatchStage.approved);
    });
  });

  group('ImportRecentBatches', () {
    testWidgets(
        'lists corrections first as rows with a state, without approved',
        (tester) async {
      await _pump(
        tester,
        const ImportRecentBatches(),
        batches: () async => _list([
          _batch('sent', 'SUBMITTED'),
          _batch('done', 'APPROVED'),
          _batch('fix', 'REJECTED', items: 4, rejected: 1),
        ]),
      );

      expect(find.text('TUS ENVÍOS'), findsOneWidget);
      expect(find.byType(SacStatusRow), findsNWidgets(2));
      expect(find.text('Hay 1 fila por corregir'), findsOneWidget);
      expect(find.text('En revisión · 3 filas'), findsOneWidget);
      expect(find.text('Envío del 12 oct 2026'), findsNWidgets(2));
      // The batch that needs a correction is above the one in review.
      expect(
        tester.getTopLeft(find.text('Hay 1 fila por corregir')).dy,
        lessThan(tester.getTopLeft(find.text('En revisión · 3 filas')).dy),
      );
    });

    testWidgets(
        'a batch still in review with a rejected row reads as a correction',
        (tester) async {
      await _pump(
        tester,
        const ImportRecentBatches(),
        batches: () async => _list([
          _batch('sent', 'SUBMITTED'),
          _batch('half', 'SUBMITTED', items: 5, rejected: 1),
        ]),
      );

      expect(find.text('Hay 1 fila por corregir'), findsOneWidget);
      expect(find.text('En revisión · 3 filas'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Hay 1 fila por corregir')).dy,
        lessThan(tester.getTopLeft(find.text('En revisión · 3 filas')).dy),
      );

      await tester.tap(find.text('Hay 1 fila por corregir'));
      await tester.pumpAndSettle();
      expect(find.text('STATUS half'), findsOneWidget);
    });

    testWidgets('says how many rows need a correction, with the plural',
        (tester) async {
      await _pump(
        tester,
        const ImportRecentBatches(),
        batches: () async => _list([
          _batch('a', 'REJECTED', rejected: 2),
          _batch('b', 'REJECTED'),
        ]),
      );

      expect(find.text('Hay 2 filas por corregir'), findsOneWidget);
      // The list carries no row statuses: still says it needs a fix.
      expect(find.text('Hay filas por corregir'), findsOneWidget);
    });

    testWidgets('opens the status screen of a batch that needs a correction',
        (tester) async {
      await _pump(
        tester,
        const ImportRecentBatches(),
        batches: () async => _list([_batch('fix', 'REJECTED', rejected: 2)]),
      );

      await tester.tap(find.text('Hay 2 filas por corregir'));
      await tester.pumpAndSettle();

      expect(find.text('STATUS fix'), findsOneWidget);
    });

    testWidgets('opens a draft in the review screen', (tester) async {
      await _pump(
        tester,
        const ImportRecentBatches(),
        batches: () async => _list([_batch('wip', 'DRAFT')]),
      );

      await tester.tap(find.text('Borrador · 3 filas'));
      await tester.pumpAndSettle();

      expect(find.text('REVIEW wip'), findsOneWidget);
    });

    testWidgets('shows at most five batches', (tester) async {
      await _pump(
        tester,
        const ImportRecentBatches(),
        batches: () async => _list([
          for (var i = 0; i < 8; i++) _batch('b$i', 'SUBMITTED'),
        ]),
      );

      expect(find.text('En revisión · 3 filas'), findsNWidgets(5));
    });

    testWidgets('takes no space when there is nothing to show', (tester) async {
      await _pump(
        tester,
        const ImportRecentBatches(),
        batches: () async => _list([_batch('done', 'APPROVED')]),
      );
      expect(find.text('TUS ENVÍOS'), findsNothing);
    });

    testWidgets('stays out of the way when the list fails to load',
        (tester) async {
      await _pump(
        tester,
        const ImportRecentBatches(),
        batches: () async => throw Exception('offline'),
      );
      expect(find.text('TUS ENVÍOS'), findsNothing);
    });
  });

  testWidgets('the upload screen shows the recent batches it is given',
      (tester) async {
    await tester.pumpWidget(testProviderScope(
      overrides: [
        certificateImportBatchListProvider.overrideWith(
          (ref, args) async => _list([_batch('fix', 'REJECTED', rejected: 1)]),
        ),
      ],
      child: wrapTestApp(
        const CertificateImportUploadView(
          recentBatches: ImportRecentBatches(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // The hero is gone: a two-line lead, what is accepted and the envíos.
    expect(find.text('Carga tu comprobante'), findsNothing);
    expect(find.textContaining('Sube un certificado o constancia'),
        findsOneWidget);
    expect(find.text('PDF de hasta 5 páginas o foto · máx. 10 MB'),
        findsOneWidget);
    expect(find.text('Hay 1 fila por corregir'), findsOneWidget);
  });
}
