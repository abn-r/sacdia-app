import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_batch.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_item.dart';
import 'package:sacdia_app/features/certificate_import/domain/usecases/get_certificate_import_batch.dart';
import 'package:sacdia_app/features/certificate_import/domain/usecases/submit_certificate_import_batch.dart';
import 'package:sacdia_app/features/certificate_import/presentation/providers/certificate_import_providers.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_review_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_status_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/certificate_import_back_button.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/import_item_row.dart';

import '../../support/catalog_fakes.dart';
import '../../support/test_app.dart';
import '../../../../support/riverpod_test_support.dart';

CertificateImportItem _row(String id, {bool active = true}) =>
    CertificateImportItem(
      id: id,
      type: CertificateImportItemType.honor,
      honorId: 10,
      detectedName: 'Nudos',
      completedAt: DateTime(2026, 4, 12),
      status: CertificateImportItemStatus.submitted,
      active: active,
    );

/// State shared by the get and submit fakes: the batch is served as the
/// member saw it when the review screen opened (four rows) until the submit
/// goes through, and as the API has it afterwards (removed row gone).
class _Api {
  bool submitted = false;

  CertificateImportBatch get batch => CertificateImportBatch(
        id: 'batch-1',
        status: submitted ? 'SUBMITTED' : 'DRAFT',
        items: submitted
            ? [_row('a'), _row('b'), _row('c')]
            : [_row('a'), _row('b'), _row('c'), _row('d')],
      );
}

class _FakeGet extends Fake implements GetCertificateImportBatch {
  _FakeGet(this.api);
  final _Api api;

  @override
  Future<Either<Failure, CertificateImportBatch>> call(
    String batchId, {
    RequestCancelToken? cancelToken,
  }) async =>
      Right(api.batch);
}

class _FakeSubmit extends Fake implements SubmitCertificateImportBatch {
  _FakeSubmit(this.api);
  final _Api api;

  @override
  Future<Either<Failure, CertificateImportBatch>> call(String batchId) async {
    api.submitted = true;
    return Right(api.batch);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestLocalization);

  testWidgets('status screen counts what was sent, not the cached review batch',
      (tester) async {
    phoneSurface(tester);
    final api = _Api();
    final router = GoRouter(
      initialLocation: RouteNames.certificateImportUpload,
      routes: [
        GoRoute(
          path: RouteNames.certificateImportUpload,
          builder: (_, __) => const Scaffold(body: Text('UPLOAD HOME')),
        ),
        GoRoute(
          path: RouteNames.certificateImportReview,
          builder: (_, state) => CertificateImportReviewRouteView(
            batchId: state.pathParameters['batchId']!,
          ),
        ),
        GoRoute(
          path: RouteNames.certificateImportStatus,
          builder: (_, state) => CertificateImportStatusRouteView(
            batchId: state.pathParameters['batchId']!,
          ),
        ),
      ],
    );
    await tester.pumpWidget(testProviderScope(
      overrides: [
        ...catalogOverrides(),
        getCertificateImportBatchProvider.overrideWithValue(_FakeGet(api)),
        submitCertificateImportBatchProvider
            .overrideWithValue(_FakeSubmit(api)),
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
            routerConfig: router,
          ),
        ),
      ),
    ));
    router.push(RouteNames.certificateImportReviewPath('batch-1'));
    await tester.pumpAndSettle();

    final review = tester.widget<CertificateImportReviewView>(
      find.byType(CertificateImportReviewView),
    );
    await review.onSubmitBatch!();
    await tester.pumpAndSettle();

    expect(find.byType(CertificateImportStatusView), findsOneWidget);
    // Three rows are in review: the removed one is not counted.
    expect(find.text('EN REVISIÓN'), findsOneWidget);
    expect(find.byType(ImportItemRow), findsNWidgets(3));
    expect(find.byType(CertificateImportReviewView), findsNothing);

    // Back from the status lands on "Carga por certificado", not on the
    // review that was already sent.
    await tester.tap(find.byType(CertificateImportBackButton));
    await tester.pumpAndSettle();
    expect(find.text('UPLOAD HOME'), findsOneWidget);
    expect(find.byType(CertificateImportReviewView), findsNothing);
  });
}
