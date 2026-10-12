import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_batch.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_file.dart';
import 'package:sacdia_app/features/certificate_import/domain/usecases/signed_certificate_import_download.dart';
import 'package:sacdia_app/features/certificate_import/presentation/providers/certificate_import_providers.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_review_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/certificate_proof_summary.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/certificate_proof_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _url = 'https://r2.example.com/proof.pdf?sig=abc';
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

class _FakeSigned extends Fake implements SignedCertificateImportDownload {
  _FakeSigned(this.answers);
  final List<Either<Failure, String>> answers;
  int calls = 0;

  @override
  Future<Either<Failure, String>> call({
    required String batchId,
    required String fileId,
  }) async =>
      answers[calls++ < answers.length ? calls - 1 : answers.length - 1];
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();
  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async =>
      jsonDecode(
              File('$path/${locale.toLanguageTag()}.json').readAsStringSync())
          as Map<String, dynamic>;
}

const _pdf = CertificateImportFile(
  id: 'file-1',
  url: '',
  name: 'certificado.pdf',
  type: 'application/pdf',
  pageCount: 3,
);
const _pdf2 = CertificateImportFile(
  id: 'file-2',
  url: '',
  name: 'otro.pdf',
  type: 'application/pdf',
);

CertificateImportBatch _batchOf(List<CertificateImportFile> files) =>
    CertificateImportBatch(id: 'batch-1', status: 'DRAFT', files: files);

Widget _app(
  Widget home, {
  _FakeSigned? signed,
  CertificateImportBatch? batch,
  Object? batchError,
}) {
  return ProviderScope(
    overrides: [
      if (signed != null)
        signedCertificateImportDownloadProvider.overrideWithValue(signed),
      certificateImportBatchProvider.overrideWith((ref, id) async {
        if (batchError != null) throw batchError;
        return batch ?? _batchOf(const []);
      }),
    ],
    child: EasyLocalization(
      supportedLocales: const [Locale('es')],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('es'),
      startLocale: const Locale('es'),
      child: Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.lightTheme,
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: home,
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

late Directory _tmp;
late String _png;
late String _localPdf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    _tmp = Directory.systemTemp.createTempSync('proof_viewer_test');
    _png = '${_tmp.path}/foto.png';
    File(_png).writeAsBytesSync(base64Decode(_pngBase64));
    _localPdf = '${_tmp.path}/acta.pdf';
    File(_localPdf).writeAsBytesSync(utf8.encode('%PDF-1.4'));
  });
  tearDownAll(() => _tmp.deleteSync(recursive: true));

  group('CertificateProofViewer', () {
    testWidgets('image with a local file opens without asking for a signed URL',
        (tester) async {
      final signed = _FakeSigned([const Right(_url)]);
      await tester.pumpWidget(_app(
        CertificateProofViewer(
          batchId: 'batch-1',
          fileId: 'file-1',
          fileName: 'foto.png',
          mimeType: 'image/png',
          localPath: _png,
        ),
        signed: signed,
      ));
      await _settle(tester);

      final viewer = tester.widget<SacImageViewer>(find.byType(SacImageViewer));
      expect(viewer.imageUrls, [_png]);
      expect(find.byType(SacPdfViewer), findsNothing);
      expect(viewer.allowShare, isFalse);
      expect(viewer.heroTag, 'certificate-proof-file-1');
      expect(signed.calls, 0);
    });

    testWidgets('a local path that no longer exists falls back to the network',
        (tester) async {
      final signed = _FakeSigned([const Right(_url)]);
      await tester.pumpWidget(_app(
        const CertificateProofViewer(
          batchId: 'batch-1',
          fileId: 'file-1',
          fileName: 'certificado.pdf',
          mimeType: 'application/pdf',
          localPath: '/nonexistent/proof.pdf',
        ),
        signed: signed,
      ));
      await _settle(tester);

      expect(tester.widget<SacPdfViewer>(find.byType(SacPdfViewer)).pdfSource,
          _url);
      expect(signed.calls, 1);
    });

    testWidgets('PDF from a signed URL opens paged on the requested page',
        (tester) async {
      final signed = _FakeSigned([const Right(_url)]);
      await tester.pumpWidget(_app(
        const CertificateProofViewer(
          batchId: 'batch-1',
          fileId: 'file-1',
          fileName: 'certificado.pdf',
          mimeType: 'application/pdf',
          pageCount: 3,
          initialPage: 2,
        ),
        signed: signed,
      ));
      await _settle(tester);

      final viewer = tester.widget<SacPdfViewer>(find.byType(SacPdfViewer));
      expect(viewer.pdfSource, _url);
      expect(viewer.horizontalPaged, isTrue);
      expect(viewer.initialPage, 2);
      expect(viewer.pageCount, 3);
      expect(viewer.allowShare, isFalse);
      expect(find.byType(SacImageViewer), findsNothing);
      expect(signed.calls, 1);
    });

    testWidgets('image from a signed URL is not persisted in the disk cache',
        (tester) async {
      await tester.pumpWidget(_app(
        const CertificateProofViewer(
          batchId: 'batch-1',
          fileId: 'file-1',
          fileName: 'foto.jpg',
          mimeType: 'image/jpeg',
        ),
        signed: _FakeSigned([const Right('https://r2.example.com/foto.jpg')]),
      ));
      await _settle(tester);

      final viewer = tester.widget<SacImageViewer>(find.byType(SacImageViewer));
      expect(viewer.imageUrls, ['https://r2.example.com/foto.jpg']);
      expect(viewer.cacheNetwork, isFalse);
    });

    testWidgets('a failing signed URL shows a translated error and retries',
        (tester) async {
      final signed = _FakeSigned([
        const Left(ServerFailure(message: 'raw backend 500 boom')),
        const Right(_url),
      ]);
      await tester.pumpWidget(_app(
        const CertificateProofViewer(
          batchId: 'batch-1',
          fileId: 'file-1',
          fileName: 'certificado.pdf',
          mimeType: 'application/pdf',
        ),
        signed: signed,
      ));
      await _settle(tester);

      expect(find.textContaining('No pudimos abrir tu comprobante'),
          findsOneWidget);
      expect(find.textContaining('raw backend'), findsNothing);
      expect(find.text('Detalle no disponible'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await _settle(tester);

      expect(signed.calls, 2, reason: 'retry asks for a fresh signed URL');
      expect(find.byType(SacPdfViewer), findsOneWidget);
      expect(find.textContaining('No pudimos abrir'), findsNothing);
    });

    testWidgets('an unconfirmed file says it is still being processed',
        (tester) async {
      await tester.pumpWidget(_app(
        const CertificateProofViewer(
          batchId: 'batch-1',
          fileId: 'file-1',
          fileName: 'foto.jpg',
          mimeType: 'image/jpeg',
        ),
        signed: _FakeSigned([
          const Left(
              ServerFailure(message: 'CERTIFICATE_IMPORT_FILE_NOT_CONFIRMED')),
        ]),
      ));
      await _settle(tester);

      expect(find.text('Tu comprobante todavía se está procesando'),
          findsOneWidget);
      expect(find.textContaining('CERTIFICATE_IMPORT'), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('without extra it recovers the file from the batch',
        (tester) async {
      final signed = _FakeSigned([const Right(_url)]);
      await tester.pumpWidget(_app(
        const CertificateProofViewer(
            batchId: 'batch-1', fileId: 'file-2', initialPage: 2),
        signed: signed,
        batch: _batchOf(const [_pdf, _pdf2]),
      ));
      await _settle(tester);

      final viewer = tester.widget<SacPdfViewer>(find.byType(SacPdfViewer));
      expect(viewer.initialPage, 2);
      expect(viewer.pageCount, isNull);
      expect(signed.calls, 1);
    });

    testWidgets('without extra and without the batch it offers a retry',
        (tester) async {
      await tester.pumpWidget(_app(
        const CertificateProofViewer(batchId: 'batch-1', fileId: 'file-1'),
        signed: _FakeSigned([const Right(_url)]),
        batchError: Exception('network down'),
      ));
      await _settle(tester);

      expect(find.textContaining('No pudimos abrir tu comprobante'),
          findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.textContaining('network down'), findsNothing);
    });

    testWidgets('a file that is not in the batch says so, with no retry',
        (tester) async {
      await tester.pumpWidget(_app(
        const CertificateProofViewer(batchId: 'batch-1', fileId: 'ghost'),
        signed: _FakeSigned([const Right(_url)]),
        batch: _batchOf(const [_pdf]),
      ));
      await _settle(tester);

      expect(find.text('No encontramos este comprobante'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });
  });

  group('SacPdfViewer paging', () {
    Future<void> pumpPdf(WidgetTester tester, {int initialPage = 2}) async {
      await tester.pumpWidget(_app(SacPdfViewer(
        pdfSource: _localPdf,
        title: 'Tu comprobante',
        horizontalPaged: true,
        initialPage: initialPage,
        pageCount: 3,
        allowShare: false,
        dark: true,
      )));
      await _settle(tester);
    }

    Finder arrow(String label) => find.ancestor(
          of: find.byTooltip(label),
          matching: find.byType(IconButton),
        );

    testWidgets('shows "Página X de N" from initialPage and walks with arrows',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      final semantics = tester.ensureSemantics();
      try {
        await pumpPdf(tester);
        expect(find.text('Página 2 de 3'), findsWidgets);
        expect(
          tester.getSemantics(arrow('Página siguiente')),
          isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true),
        );

        await tester.tap(arrow('Página siguiente'));
        await tester.pump();
        expect(find.text('Página 3 de 3'), findsWidgets);
        expect(
          tester.getSemantics(arrow('Página siguiente')),
          isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
        );

        await tester.tap(arrow('Página anterior'));
        await tester.pump();
        expect(find.text('Página 2 de 3'), findsWidgets);
      } finally {
        semantics.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('an out-of-range initialPage opens on page 1 with prev off',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      final semantics = tester.ensureSemantics();
      try {
        await pumpPdf(tester, initialPage: 9);
        expect(find.text('Página 1 de 3'), findsWidgets);
        expect(
          tester.getSemantics(arrow('Página anterior')),
          isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
        );
      } finally {
        semantics.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('CertificateProofSummary and routing', () {
    GoRouter routerFor(Widget home) => GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, __) => home),
            GoRoute(
              path: RouteNames.certificateImportProof,
              builder: (_, state) {
                final args = state.extra as CertificateProofArgs?;
                return Scaffold(
                  body: Text(
                    'proof ${state.uri} ${args?.fileName} ${args?.pageCount}',
                  ),
                );
              },
            ),
          ],
        );

    Widget host(GoRouter router) => ProviderScope(
          child: EasyLocalization(
            supportedLocales: const [Locale('es')],
            path: 'assets/translations',
            assetLoader: const _FileAssetLoader(),
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
        );

    testWidgets('review opens the proof by batch and file even with no rows',
        (tester) async {
      final router = routerFor(CertificateImportReviewView(
        initialBatch: _batchOf(const [_pdf, _pdf2]),
      ));
      await tester.pumpWidget(host(router));
      await _settle(tester);

      expect(find.text('Tu comprobante'), findsOneWidget);
      expect(find.text('certificado.pdf'), findsOneWidget);
      expect(find.text('PDF · 3 páginas · +1 archivo'), findsOneWidget);

      await tester.tap(find.text('Tu comprobante'));
      await tester.pumpAndSettle();

      expect(
          find.text('proof /certificate-import/batch-1/proof/file-1 '
              'certificado.pdf 3'),
          findsOneWidget);
      expect(find.text('Detalle no disponible'), findsNothing);
    });

    testWidgets('a PDF without page_count says just "PDF"; images say "Foto"',
        (tester) async {
      const noCount = CertificateImportFile(
          id: 'f', url: '', name: 'a.pdf', type: 'application/pdf');
      const photo = CertificateImportFile(
          id: 'g', url: '', name: 'a.jpg', type: 'image/jpeg');
      for (final (file, text) in [(noCount, 'PDF'), (photo, 'Foto')]) {
        await tester.pumpWidget(_app(Scaffold(
            body: CertificateProofSummary(batchId: 'b', files: [file]))));
        await _settle(tester);
        expect(find.text(text), findsOneWidget);
      }
    });

    test('the proof path is built from batch, file and page', () {
      expect(RouteNames.certificateImportProofPath('b1', 'f1'),
          '/certificate-import/b1/proof/f1');
      expect(RouteNames.certificateImportProofPath('b1', 'f1', page: 2),
          '/certificate-import/b1/proof/f1?page=2');
      expect(RouteNames.certificateImportProof, isNot(contains(':itemId')));
    });
  });
}
