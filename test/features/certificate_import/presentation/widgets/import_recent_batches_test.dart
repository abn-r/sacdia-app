import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
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
  DateTime? modifiedAt,
}) =>
    CertificateImportBatchSummary(
      id: id,
      status: status,
      modifiedAt: modifiedAt ?? DateTime(2026, 10, 12, 12),
      itemCount: items,
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

  group('ImportRecentBatches', () {
    testWidgets('lists corrections first with a status chip, without approved',
        (tester) async {
      await _pump(
        tester,
        const ImportRecentBatches(),
        batches: () async => _list([
          _batch('sent', 'SUBMITTED'),
          _batch('done', 'APPROVED'),
          _batch('fix', 'REJECTED', items: 4),
        ]),
      );

      expect(find.text('Tus envíos recientes'), findsOneWidget);
      expect(find.text('Corrección'), findsOneWidget);
      expect(find.text('En revisión'), findsOneWidget);
      expect(find.text('Aprobado'), findsNothing);
      expect(find.text('12/10/2026 · Filas: 4'), findsOneWidget);
      // The batch that needs a correction is above the one in review.
      expect(
        tester.getTopLeft(find.text('Corrección')).dy,
        lessThan(tester.getTopLeft(find.text('En revisión')).dy),
      );
    });

    testWidgets('opens the status screen of a batch that needs a correction',
        (tester) async {
      await _pump(
        tester,
        const ImportRecentBatches(),
        batches: () async => _list([_batch('fix', 'REJECTED')]),
      );

      await tester.tap(find.text('Corrección'));
      await tester.pumpAndSettle();

      expect(find.text('STATUS fix'), findsOneWidget);
    });

    testWidgets('opens a draft in the review screen', (tester) async {
      await _pump(
        tester,
        const ImportRecentBatches(),
        batches: () async => _list([_batch('wip', 'DRAFT')]),
      );

      await tester.tap(find.text('Borrador'));
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

      expect(find.text('En revisión'), findsNWidgets(5));
    });

    testWidgets('takes no space when there is nothing to show', (tester) async {
      await _pump(
        tester,
        const ImportRecentBatches(),
        batches: () async => _list([_batch('done', 'APPROVED')]),
      );
      expect(find.text('Tus envíos recientes'), findsNothing);
    });

    testWidgets('stays out of the way when the list fails to load',
        (tester) async {
      await _pump(
        tester,
        const ImportRecentBatches(),
        batches: () async => throw Exception('offline'),
      );
      expect(find.text('Tus envíos recientes'), findsNothing);
    });
  });

  testWidgets('the upload screen shows the recent batches it is given',
      (tester) async {
    await tester.pumpWidget(testProviderScope(
      overrides: [
        certificateImportBatchListProvider.overrideWith(
          (ref, args) async => _list([_batch('fix', 'REJECTED')]),
        ),
      ],
      child: wrapTestApp(
        const CertificateImportUploadView(
          recentBatches: ImportRecentBatches(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Carga tu comprobante'), findsOneWidget);
    expect(find.text('Corrección'), findsOneWidget);
  });
}
