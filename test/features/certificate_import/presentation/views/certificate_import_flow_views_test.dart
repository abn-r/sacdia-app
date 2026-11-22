import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_batch.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_file.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_item.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_payloads.dart';
import 'package:sacdia_app/features/certificate_import/presentation/controllers/certificate_import_upload_controller.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_status_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_upload_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/certificate_import_proof_card.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/import_item_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/riverpod_test_support.dart';

Widget _wrap(Widget child) => testProviderScope(
      child: _localized(child),
    );

Widget _localized(Widget child) => EasyLocalization(
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
          home: child,
        ),
      ),
    );

/// Phone-sized surface so cards below the hero are not hidden by the dock.
void _phoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(_wrap(child));
  await tester.pump();
  await tester.pump();
}

/// Opens the "add proof" sheet and taps [option] (camera, gallery or files).
Future<void> _choose(WidgetTester tester, String option) async {
  // First time the dock offers "Agregar comprobante"; with a proof chosen
  // the way to pick another one is "Cambiar" on its preview.
  final add = find.text('Agregar comprobante');
  await tester.tap(add.evaluate().isNotEmpty ? add : find.text('Cambiar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

CertificateImportLocalProof _proof({
  String name = 'comprobante.jpg',
  String mimeType = 'image/jpeg',
  int size = 128,
}) =>
    CertificateImportLocalProof(
      localPath: '/tmp/$name',
      fileName: name,
      mimeType: mimeType,
      fileSize: size,
    );

CertificateImportBatch _batch({bool complete = false, bool rejected = false}) {
  return CertificateImportBatch(
    id: 'batch-1',
    status: rejected ? 'REJECTED' : 'DRAFT',
    files: const [
      CertificateImportFile(
        id: 'file-1',
        url: 'mock://receipt.jpg',
        name: 'Acampada Sinaí 2026',
        type: 'image/jpeg',
      ),
    ],
    items: [
      CertificateImportItem(
        id: 'honor-1',
        type: CertificateImportItemType.honor,
        honorId: complete ? 10 : null,
        detectedName: 'Primeros Auxilios',
        completedAt: complete ? DateTime(2026, 4, 12) : null,
        ocrConfidence: 0.82,
        status: complete
            ? CertificateImportItemStatus.ready
            : CertificateImportItemStatus.needsReview,
        rejectionReason:
            rejected ? 'La fecha no coincide con el comprobante' : null,
      ),
      CertificateImportItem(
        id: 'class-1',
        type: CertificateImportItemType.clazz,
        classId: 3,
        detectedName: 'Amigo',
        completedAt: DateTime(2026, 4, 12),
        ocrConfidence: 0.91,
        status: CertificateImportItemStatus.ready,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting('es');
  });

  group('Certificate import routing', () {
    test('declares route names for upload, review and imported proof', () {
      expect(RouteNames.certificateImportUpload, '/certificate-import');
      expect(RouteNames.certificateImportReviewPath('batch-1'),
          '/certificate-import/batch-1/review');
      expect(RouteNames.certificateImportProofPath('batch-1', 'file-1'),
          '/certificate-import/batch-1/proof/file-1');
      expect(routerProvider, isNotNull);
    });
  });

  group('CertificateImportUploadView', () {
    testWidgets('explains the five-page PDF limit before uploading',
        (tester) async {
      await _pump(tester, const CertificateImportUploadView());
      expect(find.textContaining('PDF de hasta 5 páginas'), findsOneWidget);
    });

    testWidgets('pulling down reloads the member\'s sends', (tester) async {
      var reloads = 0;
      _phoneSurface(tester);
      await _pump(
        tester,
        CertificateImportUploadView(onRefresh: () async => reloads++),
      );

      await tester.fling(find.textContaining('PDF de hasta 5 páginas'),
          const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(reloads, 1);
    });

    final pdfMessages = <String, String>{
      'CERTIFICATE_IMPORT_PDF_TOO_MANY_PAGES':
          'Divide el documento o guarda solo las páginas del certificado (hasta 5) y vuelve a subirlo.',
      'CERTIFICATE_IMPORT_PDF_ENCRYPTED':
          'Quita la contraseña o la protección del archivo y vuelve a subirlo.',
      'CERTIFICATE_IMPORT_PDF_INVALID':
          'Vuelve a guardarlo como PDF desde la app donde lo tienes y súbelo otra vez.',
    };
    for (final entry in pdfMessages.entries) {
      testWidgets('localizes ${entry.key} without exposing technical details',
          (tester) async {
        _phoneSurface(tester);
        await _pump(
          tester,
          CertificateImportUploadView(
            onSubmitProofs: (_) async =>
                throw ServerFailure(message: entry.key, code: 400),
            onPickFile: () async => const CertificateImportLocalProof(
              localPath: '/private/internal.pdf',
              fileName: 'comprobante.pdf',
              mimeType: 'application/pdf',
              fileSize: 128,
            ),
          ),
        );
        await _choose(tester, 'Elegir archivo');
        await tester.pump();
        await tester.tap(find.text('Leer comprobante'));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.textContaining(entry.key), findsNothing);
        expect(find.textContaining('/private/internal.pdf'), findsNothing);
        final upload = tester.widget<SacButton>(
          find.widgetWithText(SacButton, 'Leer comprobante'),
        );
        expect(upload.onPressed, isNotNull);
      });
    }

    testWidgets('never shows unknown failure text from the backend',
        (tester) async {
      _phoneSurface(tester);
      await _pump(
        tester,
        CertificateImportUploadView(
          onSubmitProofs: (_) async => throw const ServerFailure(
            message: 'ECONNRESET at /srv/api/upload.ts:42',
          ),
          onPickFile: () async => const CertificateImportLocalProof(
            localPath: '/tmp/proof.pdf',
            fileName: 'comprobante.pdf',
            mimeType: 'application/pdf',
            fileSize: 128,
          ),
        ),
      );
      await _choose(tester, 'Elegir archivo');
      await tester.pump();
      await tester.tap(find.text('Leer comprobante'));
      await tester.pumpAndSettle();
      expect(find.text('Algo salió mal'), findsOneWidget);
      expect(find.text('No pudimos subir tu comprobante. Inténtalo de nuevo.'),
          findsOneWidget);
      expect(find.textContaining('ECONNRESET'), findsNothing);
    });

    testWidgets('PDF_BUSY shows the busy card and retry runs the submit again',
        (tester) async {
      _phoneSurface(tester);
      var calls = 0;
      await _pump(
        tester,
        CertificateImportUploadView(
          onSubmitProofs: (_) async {
            calls++;
            throw const ServerFailure(
              message: 'CERTIFICATE_IMPORT_PDF_BUSY',
              code: 429,
            );
          },
          onPickFile: () async =>
              _proof(name: 'acta.pdf', mimeType: 'application/pdf'),
        ),
      );
      await _choose(tester, 'Elegir archivo');
      await tester.tap(find.text('Leer comprobante'));
      await tester.pumpAndSettle();

      expect(find.text('Hay mucha demanda en este momento'), findsOneWidget);
      expect(find.textContaining('CERTIFICATE_IMPORT'), findsNothing);
      expect(calls, 1);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });

    testWidgets(
        'offline shows the no-connection card and keeps the submit enabled',
        (tester) async {
      _phoneSurface(tester);
      await _pump(
        tester,
        CertificateImportUploadView(
          onSubmitProofs: (_) async => throw const ServerFailure(
            message: 'x',
            errorCode: 'NETWORK',
          ),
          onPickFile: () async => _proof(),
        ),
      );
      await _choose(tester, 'Elegir archivo');
      await tester.tap(find.text('Leer comprobante'));
      await tester.pumpAndSettle();

      expect(find.text('No hay conexión'), findsOneWidget);
      expect(find.textContaining('Tu archivo sigue aquí'), findsOneWidget);
      // The file stays selected: submitting again is still possible.
      final submit = tester.widget<SacButton>(
        find.widgetWithText(SacButton, 'Leer comprobante'),
      );
      expect(submit.onPressed, isNotNull);
    });

    testWidgets('has no read action until a proof file is selected',
        (tester) async {
      var uploadCalls = 0;
      await _pump(
        tester,
        CertificateImportUploadView(
          onSubmitProofs: (_) async => uploadCalls++,
          onPickFile: () async => const CertificateImportLocalProof(
            localPath: '/tmp/proof.jpg',
            fileName: 'image_picker_8E67A1.jpg',
            mimeType: 'image/jpeg',
            fileSize: 128,
          ),
        ),
      );

      // ONE fixed action: no disabled "Leer comprobante" beside it.
      expect(find.text('Agregar comprobante'), findsOneWidget);
      expect(find.text('Leer comprobante'), findsNothing);
      expect(find.byType(SacButton), findsOneWidget);
      expect(find.text('Tu comprobante'), findsNothing);
      expect(uploadCalls, 0);

      await _choose(tester, 'Elegir archivo');
      await tester.pump();

      // A preview with the kind and size, never the technical file name.
      expect(find.text('Tu comprobante'), findsOneWidget);
      expect(find.text('Foto · 1 KB'), findsOneWidget);
      expect(find.text('Cambiar'), findsOneWidget);
      expect(find.textContaining('image_picker'), findsNothing);
      // The action turned into "Leer comprobante".
      expect(find.text('Agregar comprobante'), findsNothing);
      expect(find.byType(SacButton), findsOneWidget);

      await tester.tap(find.text('Leer comprobante'));
      await tester.pump();

      expect(uploadCalls, 1);
    });

    testWidgets('a PDF previews with a page icon and its size', (tester) async {
      await _pump(
        tester,
        CertificateImportUploadView(
          onPickFile: () async => _proof(
            name: 'acta.pdf',
            mimeType: 'application/pdf',
            size: 340 * 1024,
          ),
        ),
      );
      await _choose(tester, 'Elegir archivo');

      expect(find.text('Tu comprobante'), findsOneWidget);
      expect(find.text('PDF · 340 KB'), findsOneWidget);
      expect(find.text('acta.pdf'), findsNothing);
    });

    testWidgets('"Cambiar" picks another proof and keeps ONE action',
        (tester) async {
      var next = _proof(name: 'uno.jpg');
      await _pump(
        tester,
        CertificateImportUploadView(onPickGallery: () async => next),
      );
      await _choose(tester, 'Elegir de la galería');
      expect(find.text('Foto · 1 KB'), findsOneWidget);

      next = _proof(name: 'dos.jpg', size: 2 * 1024 * 1024);
      await _choose(tester, 'Elegir de la galería');
      expect(find.textContaining('Foto · 2'), findsOneWidget);
      expect(find.byType(SacButton), findsOneWidget);
    });

    testWidgets('keeps the read action away when proof selection is cancelled',
        (tester) async {
      var uploadCalls = 0;
      await _pump(
        tester,
        CertificateImportUploadView(
          onSubmitProofs: (_) async => uploadCalls++,
          onPickFile: () async => null,
          onPickCamera: () async => null,
        ),
      );

      await _choose(tester, 'Elegir archivo');
      await tester.pumpAndSettle();

      expect(find.text('Tu comprobante'), findsNothing);
      expect(find.text('Leer comprobante'), findsNothing);
      expect(find.text('Agregar comprobante'), findsOneWidget);

      await _choose(tester, 'Tomar foto');
      await tester.pumpAndSettle();

      expect(find.text('Tu comprobante'), findsNothing);
      expect(find.text('Leer comprobante'), findsNothing);
      expect(uploadCalls, 0);
    });
    testWidgets('lists camera, gallery and files in one bottom sheet',
        (tester) async {
      await _pump(tester, const CertificateImportUploadView());
      expect(find.text('Tomar foto'), findsNothing);

      await tester.tap(find.text('Agregar comprobante'));
      await tester.pumpAndSettle();

      expect(find.text('Tomar foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
      expect(find.text('Elegir archivo'), findsOneWidget);
    });

    testWidgets('gallery option uses the gallery picker and selects the image',
        (tester) async {
      var galleryCalls = 0;
      var cameraCalls = 0;
      var fileCalls = 0;
      await _pump(
        tester,
        CertificateImportUploadView(
          onPickCamera: () async {
            cameraCalls++;
            return null;
          },
          onPickFile: () async {
            fileCalls++;
            return null;
          },
          onPickGallery: () async {
            galleryCalls++;
            return _proof(name: 'carrete.png', mimeType: 'image/png');
          },
        ),
      );

      await _choose(tester, 'Elegir de la galería');

      expect([galleryCalls, cameraCalls, fileCalls], [1, 0, 0]);
      expect(find.text('Tu comprobante'), findsOneWidget);
      expect(find.text('carrete.png'), findsNothing);
    });

    testWidgets('route picker requests ImageSource.gallery for the gallery',
        (tester) async {
      final dir = Directory.systemTemp.createTempSync('cert_gallery_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/foto.jpg')..writeAsBytesSync([1, 2, 3]);

      final sources = <ImageSource>[];
      final proof = await tester.runAsync(() =>
          CertificateImportUploadRouteView.pickImageProof(
            ImageSource.gallery,
            pickImage: (source) async {
              sources.add(source);
              return XFile(file.path, name: 'foto.jpg', mimeType: 'image/jpeg');
            },
          ));

      expect(sources, [ImageSource.gallery]);
      expect(proof?.fileName, 'foto.jpg');
      expect(proof?.mimeType, 'image/jpeg');
      expect(proof?.fileSize, 3);
    });

    for (final picker in [
      'Tomar foto',
      'Elegir de la galería',
      'Elegir archivo'
    ]) {
      testWidgets('$picker rejects unsupported types', (tester) async {
        Future<CertificateImportLocalProof?> unsupported() async =>
            _proof(name: 'animacion.gif', mimeType: 'image/gif');
        await _pump(
          tester,
          CertificateImportUploadView(
            onSubmitProofs: (_) async {},
            onPickCamera: unsupported,
            onPickGallery: unsupported,
            onPickFile: unsupported,
          ),
        );

        await _choose(tester, picker);

        expect(
          find.text(
              'Formato no admitido. Usa un PDF o una imagen JPEG, PNG o WebP.'),
          findsOneWidget,
        );
        expect(find.text('Tu comprobante'), findsNothing);
        expect(find.text('Leer comprobante'), findsNothing);
      });

      testWidgets('$picker rejects files over 10 MiB', (tester) async {
        Future<CertificateImportLocalProof?> huge() async =>
            _proof(size: 10 * 1024 * 1024 + 1);
        await _pump(
          tester,
          CertificateImportUploadView(
            onPickCamera: huge,
            onPickGallery: huge,
            onPickFile: huge,
          ),
        );

        await _choose(tester, picker);

        expect(
            find.text(
                'El archivo pesa más de 10 MB. Elige uno más liviano o toma la foto de nuevo.'),
            findsOneWidget);
        expect(find.text('Tu comprobante'), findsNothing);
      });
    }

    testWidgets('accepts exactly 10 MiB and a PDF', (tester) async {
      await _pump(
        tester,
        CertificateImportUploadView(
          onPickGallery: () async => _proof(size: 10 * 1024 * 1024),
          onPickFile: () async =>
              _proof(name: 'acta.pdf', mimeType: 'application/pdf'),
        ),
      );

      await _choose(tester, 'Elegir de la galería');
      expect(find.textContaining('Foto · 10'), findsOneWidget);

      await _choose(tester, 'Elegir archivo');
      expect(find.text('PDF · 1 KB'), findsOneWidget);
      expect(find.textContaining('Formato no admitido'), findsNothing);
    });

    testWidgets('a rejected pick clears the previous valid selection',
        (tester) async {
      var next = _proof();
      await _pump(
        tester,
        CertificateImportUploadView(onPickGallery: () async => next),
      );

      await _choose(tester, 'Elegir de la galería');
      expect(find.text('Tu comprobante'), findsOneWidget);

      next = _proof(name: 'raro.heic', mimeType: 'image/heic');
      await _choose(tester, 'Elegir de la galería');
      expect(find.text('Tu comprobante'), findsNothing);
      expect(find.textContaining('Formato no admitido'), findsOneWidget);
    });

    testWidgets('shows ONE state panel with skeleton rows, not a spinner',
        (tester) async {
      final completer = Completer<void>();
      final phase = ValueNotifier(CertificateImportUploadPhase.uploading);
      addTearDown(phase.dispose);
      await _pump(
        tester,
        CertificateImportUploadView(
          phase: phase,
          onSubmitProofs: (_) => completer.future,
          onPickFile: () async => _proof(),
        ),
      );
      await _choose(tester, 'Elegir archivo');
      await tester.tap(find.text('Leer comprobante'));
      await tester.pump();

      expect(find.byType(SacStatePanel), findsOneWidget);
      expect(find.text('Subiendo tu comprobante'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // "Encontrado" as three skeleton rows that the review fills in later.
      expect(find.text('ENCONTRADO'), findsOneWidget);
      expect(find.byType(SacSkeletonBox), findsNWidgets(9));
      // Not the segmented Subir / Leer / Revisar bar.
      expect(find.text('Subir'), findsNothing);
      expect(find.text('Revisar'), findsNothing);
      // Busy: no source picker, no read action.
      expect(find.widgetWithText(SacButton, 'Leer comprobante'), findsNothing);
      expect(find.text('Agregar comprobante'), findsNothing);

      phase.value = CertificateImportUploadPhase.reading;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Leyendo tu comprobante'), findsOneWidget);
      expect(find.text('Subiendo tu comprobante'), findsNothing);
      expect(
        find.text('Buscamos líneas que empiecen con «Especialidad:» o '
            '«Clase:».'),
        findsOneWidget,
      );
      // Still ONE panel, never two.
      expect(find.byType(SacStatePanel), findsOneWidget);

      completer.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(SacStatePanel), findsNothing);
      expect(find.text('Leer comprobante'), findsOneWidget);
    });

    testWidgets('under Reduced Motion the skeleton is static', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final completer = Completer<void>();
      await _pump(
        tester,
        CertificateImportUploadView(
          onSubmitProofs: (_) => completer.future,
          onPickFile: () async => _proof(),
        ),
      );
      await _choose(tester, 'Elegir archivo');
      await tester.tap(find.text('Leer comprobante'));
      await tester.pump();

      expect(find.text('Subiendo tu comprobante'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SacSkeletonBox), findsNWidgets(9));
      expect(find.byType(ShaderMask), findsNothing);

      completer.complete();
      await tester.pump();
      await tester.pump();
    });
  });

  group('CertificateImportUploadView waiting', () {
    Future<void> startUpload(
      WidgetTester tester, {
      required ValueNotifier<CertificateImportUploadPhase> phase,
      required ValueNotifier<double> progress,
      required ValueNotifier<bool> slow,
      required Completer<void> done,
      VoidCallback? onCancel,
      VoidCallback? onSkipWait,
    }) async {
      _phoneSurface(tester);
      addTearDown(phase.dispose);
      addTearDown(progress.dispose);
      addTearDown(slow.dispose);
      await _pump(
        tester,
        CertificateImportUploadView(
          phase: phase,
          progress: progress,
          slow: slow,
          onCancel: onCancel,
          onSkipWait: onSkipWait,
          onSubmitProofs: (_) => done.future,
          onPickFile: () async => _proof(),
        ),
      );
      await _choose(tester, 'Elegir archivo');
      await tester.tap(find.text('Leer comprobante'));
      await tester.pump();
    }

    for (final reduced in [false, true]) {
      final suffix = reduced ? ' (reduced motion)' : '';

      testWidgets(
          'shows the real progress in the panel and Cancelar while uploading$suffix',
          (tester) async {
        if (reduced) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
              tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        }
        final phase = ValueNotifier(CertificateImportUploadPhase.uploading);
        final progress = ValueNotifier(0.0);
        final slow = ValueNotifier(false);
        final done = Completer<void>();
        var cancelled = 0;
        await startUpload(
          tester,
          phase: phase,
          progress: progress,
          slow: slow,
          done: done,
          onCancel: () => cancelled++,
        );

        // No segmented Subir / Leer / Revisar bar: one panel.
        expect(find.text('Subir'), findsNothing);
        expect(find.text('Leer'), findsNothing);
        expect(find.text('Revisar'), findsNothing);
        expect(find.byType(SacStatePanel), findsOneWidget);
        expect(find.text('Subiendo tu comprobante'), findsOneWidget);

        progress.value = 0.64;
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Subiendo 64 %'), findsOneWidget);
        expect(find.byType(SacStatePanel), findsOneWidget);
        final bar = tester.widget<SacTweenedBar>(find.byType(SacTweenedBar));
        expect(bar.value, 0.64);

        await tester.tap(find.text('Cancelar'));
        expect(cancelled, 1);

        done.complete();
        await tester.pump(const Duration(milliseconds: 300));
      });

      testWidgets(
          'reading drops the bar and Cancelar, and offers to skip when slow$suffix',
          (tester) async {
        if (reduced) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
              tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        }
        final phase = ValueNotifier(CertificateImportUploadPhase.uploading);
        final progress = ValueNotifier(1.0);
        final slow = ValueNotifier(false);
        final done = Completer<void>();
        var skipped = 0;
        await startUpload(
          tester,
          phase: phase,
          progress: progress,
          slow: slow,
          done: done,
          onSkipWait: () => skipped++,
        );

        phase.value = CertificateImportUploadPhase.reading;
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Leyendo tu comprobante'), findsOneWidget);
        expect(find.byType(SacTweenedBar), findsNothing);
        expect(find.text('Cancelar'), findsNothing);
        expect(find.text('Seguir sin esperar'), findsNothing);

        slow.value = true;
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('Sigue leyendo'), findsOneWidget);
        await tester.tap(find.text('Seguir sin esperar'));
        expect(skipped, 1);

        done.complete();
        await tester.pump(const Duration(milliseconds: 300));
      });
    }

    testWidgets('announces the state in steps of 25 % for assistive tech',
        (tester) async {
      final phase = ValueNotifier(CertificateImportUploadPhase.uploading);
      final progress = ValueNotifier(0.0);
      final done = Completer<void>();
      await startUpload(
        tester,
        phase: phase,
        progress: progress,
        slow: ValueNotifier(false),
        done: done,
      );
      final semantics = tester.ensureSemantics();
      progress.value = 0.64;
      await tester.pump(const Duration(milliseconds: 300));
      // The screen shows 64 %, a screen reader hears 50 %: not flooded.
      expect(find.text('Subiendo 64 %'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Subiendo 50 %')), findsOneWidget);

      phase.value = CertificateImportUploadPhase.reading;
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel(RegExp(r'^Leyendo tu comprobante')),
          findsOneWidget);
      semantics.dispose();
      done.complete();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('a cancelled upload returns to the file without an error',
        (tester) async {
      _phoneSurface(tester);
      await _pump(
        tester,
        CertificateImportUploadView(
          onSubmitProofs: (_) async =>
              throw const CertificateImportUploadCancelled(),
          onPickFile: () async => _proof(),
        ),
      );
      await _choose(tester, 'Elegir archivo');
      await tester.tap(find.text('Leer comprobante'));
      await tester.pumpAndSettle();

      expect(find.text('Algo salió mal'), findsNothing);
      expect(find.text('Tu comprobante'), findsOneWidget);
      final submit = tester.widget<SacButton>(
        find.widgetWithText(SacButton, 'Leer comprobante'),
      );
      expect(submit.onPressed, isNotNull);
    });
  });

  group('CertificateImportStatusView', () {
    CertificateImportItem row(
      String id, {
      required CertificateImportItemStatus status,
      bool active = true,
      String? reason,
      String name = 'Nudos',
      CertificateImportItemType type = CertificateImportItemType.honor,
    }) =>
        CertificateImportItem(
          id: id,
          type: type,
          honorId: type == CertificateImportItemType.honor ? 10 : null,
          classId: type == CertificateImportItemType.clazz ? 3 : null,
          detectedName: name,
          completedAt: DateTime(2026, 4, 12),
          status: status,
          rejectionReason: reason,
          active: active,
        );

    Future<void> showBatch(
      WidgetTester tester,
      List<CertificateImportItem> items, {
      String status = 'SUBMITTED',
    }) async {
      _phoneSurface(tester);
      await _pump(
        tester,
        CertificateImportStatusView(
          batch: CertificateImportBatch(
            id: 'batch-1',
            status: status,
            items: items,
          ),
          onResubmitItem: (_, __) async {},
        ),
      );
    }

    testWidgets('pulling down reloads to see the reviewer decisions',
        (tester) async {
      var reloads = 0;
      _phoneSurface(tester);
      await _pump(
        tester,
        CertificateImportStatusView(
          batch: _batch(rejected: true),
          onRefresh: () async => reloads++,
        ),
      );

      await tester.fling(
          find.byType(SacStatePanel), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(reloads, 1);
    });

    testWidgets('without a reload there is no pull to refresh', (tester) async {
      await _pump(tester, CertificateImportStatusView(batch: _batch()));
      expect(find.byType(RefreshIndicator), findsNothing);
    });

    testWidgets('shows the state panel, the reason and every row by group',
        (tester) async {
      await _pump(
        tester,
        CertificateImportStatusView(
          batch: _batch(rejected: true),
          onResubmitItem: (_, __) async {},
        ),
      );

      // The app bar is the batch name.
      expect(find.text('Acampada Sinaí 2026'), findsOneWidget);
      expect(find.byType(SacStatePanel), findsOneWidget);
      expect(find.text('Hay 1 fila por corregir'), findsOneWidget);
      expect(find.text('Ver todos los estados'), findsOneWidget);
      // Por corregir: the reason as the subtitle, and "Corregir".
      expect(find.text('POR CORREGIR'), findsOneWidget);
      expect(
          find.text('La fecha no coincide con el comprobante'), findsOneWidget);
      expect(find.text('Corregir'), findsOneWidget);
      // The other row is no longer hidden: it is in review.
      expect(find.text('EN REVISIÓN'), findsOneWidget);
      expect(find.byType(ImportItemRow), findsNWidgets(2));
    });

    testWidgets('groups ALL rows: Por corregir, En revisión and Aprobadas',
        (tester) async {
      await showBatch(tester, [
        row('a', status: CertificateImportItemStatus.approved, name: 'Amigo'),
        row('r',
            status: CertificateImportItemStatus.rejected,
            reason: 'Falta la firma',
            name: 'Nudos'),
        row('s', status: CertificateImportItemStatus.submitted, name: 'Fuego'),
        row('t',
            status: CertificateImportItemStatus.resubmitted, name: 'Cuerdas'),
        row('n',
            status: CertificateImportItemStatus.needsReview, name: 'Mapas'),
      ]);

      List<String> idsIn(String keyName) => tester
          .widgetList<ImportItemRow>(find.descendant(
            of: find.byKey(ValueKey(keyName)),
            matching: find.byType(ImportItemRow),
          ))
          .map((r) => r.item.id)
          .toList();

      expect(idsIn('status-group-fix'), ['r']);
      expect(idsIn('status-group-review'), ['s', 't', 'n']);
      expect(idsIn('status-group-approved'), ['a']);
      // The order of the groups: fix first.
      expect(
        tester.getTopLeft(find.text('POR CORREGIR')).dy,
        lessThan(tester.getTopLeft(find.text('EN REVISIÓN')).dy),
      );
      expect(
        tester.getTopLeft(find.text('EN REVISIÓN')).dy,
        lessThan(tester.getTopLeft(find.text('APROBADAS')).dy),
      );
      // A resent row says so.
      expect(find.textContaining('Reenviada'), findsOneWidget);
    });

    group('batch state in the panel', () {
      testWidgets('En revisión: everything sent and waiting', (tester) async {
        await showBatch(tester, [
          row('a', status: CertificateImportItemStatus.submitted),
          row('b', status: CertificateImportItemStatus.submitted),
        ]);
        expect(find.text('En revisión'), findsWidgets);
        expect(find.text('Tu Campo Local está revisando este envío.'),
            findsOneWidget);
        expect(find.text('POR CORREGIR'), findsNothing);
        expect(find.text('APROBADAS'), findsNothing);
      });

      testWidgets('Hay N filas por corregir, with the plural', (tester) async {
        await showBatch(tester, [
          row('a', status: CertificateImportItemStatus.rejected, reason: 'x'),
          row('b', status: CertificateImportItemStatus.rejected, reason: 'y'),
          row('c', status: CertificateImportItemStatus.submitted),
        ]);
        expect(find.text('Hay 2 filas por corregir'), findsOneWidget);
        expect(
          find.text('Corrígelas y reenvíalas; el resto sigue en revisión.'),
          findsOneWidget,
        );
      });

      testWidgets('Aprobado en parte: some approved, the rest in review',
          (tester) async {
        await showBatch(
          tester,
          [
            row('a', status: CertificateImportItemStatus.approved),
            row('b', status: CertificateImportItemStatus.submitted),
          ],
          status: 'PARTIALLY_APPROVED',
        );
        expect(find.text('Aprobado en parte'), findsOneWidget);
        expect(find.text('POR CORREGIR'), findsNothing);
      });

      testWidgets('Aprobado: every row approved', (tester) async {
        await showBatch(
          tester,
          [
            row('a', status: CertificateImportItemStatus.approved),
            row('b', status: CertificateImportItemStatus.approved),
          ],
          status: 'APPROVED',
        );
        expect(find.text('Aprobado'), findsOneWidget);
        expect(find.text('EN REVISIÓN'), findsNothing);
        expect(find.text('APROBADAS'), findsOneWidget);
      });
    });

    testWidgets('"Ver todos los estados" opens the states sheet',
        (tester) async {
      await showBatch(tester, [
        row('a', status: CertificateImportItemStatus.rejected, reason: 'x'),
        row('b', status: CertificateImportItemStatus.submitted),
      ]);

      await tester.tap(find.byType(SacStatePanel));
      await tester.pumpAndSettle();

      expect(find.byType(SacStatesSheet), findsOneWidget);
      expect(find.text('Estados del envío'), findsOneWidget);
      final sheet = find.byType(SacStatesSheet);
      for (final label in [
        'Enviado',
        'En revisión',
        'Aprobado',
        'Por corregir'
      ]) {
        expect(find.descendant(of: sheet, matching: find.text(label)),
            findsOneWidget,
            reason: label);
      }
    });

    testWidgets('does not list or count the rows the member removed',
        (tester) async {
      // Three removed rows and two sent: only the two sent wait for review.
      await showBatch(tester, [
        row('a', status: CertificateImportItemStatus.submitted),
        row('b', status: CertificateImportItemStatus.submitted),
        for (final id in ['x', 'y', 'z'])
          row(id,
              status: CertificateImportItemStatus.needsReview, active: false),
      ]);

      expect(find.byType(ImportItemRow), findsNWidgets(2));
      expect(find.text('EN REVISIÓN'), findsOneWidget);
    });

    testWidgets('a removed rejected row does not ask for corrections',
        (tester) async {
      await showBatch(tester, [
        row('a', status: CertificateImportItemStatus.approved),
        row('r', status: CertificateImportItemStatus.rejected, active: false),
      ]);

      expect(find.textContaining('por corregir'), findsNothing);
      expect(find.text('POR CORREGIR'), findsNothing);
      // The only row left is approved, so the whole batch is.
      expect(find.text('Aprobado'), findsOneWidget);
    });
  });

  group('CertificateImportProofCard', () {
    testWidgets('renders simplified imported proof from item props',
        (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: CertificateImportProofCard(
              item: _batch(complete: true).items.first),
        ),
      );

      expect(find.text('Registro importado'), findsOneWidget);
      expect(find.text('Primeros Auxilios'), findsOneWidget);
      expect(find.text('12/04/2026'), findsOneWidget);
    });

    testWidgets('shows institutional notice for GM-02 class item',
        (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: CertificateImportProofCard(
            item: CertificateImportItem(
              id: 'inst-1',
              type: CertificateImportItemType.clazz,
              classAssetCode: 'GM-02',
              detectedName: 'Guía Mayor Avanzado',
              completedAt: DateTime(2024, 6, 15),
              status: CertificateImportItemStatus.approved,
            ),
          ),
        ),
      );

      expect(find.text('Registro importado'), findsOneWidget);
      expect(find.text('Guía Mayor Avanzado'), findsOneWidget);
      expect(
        find.text('Revisión institucional: aprobar no crea inscripción.'),
        findsOneWidget,
      );
    });

    testWidgets('shows GM replacement notice for GM-01 class item',
        (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: CertificateImportProofCard(
            item: CertificateImportItem(
              id: 'gm01-1',
              type: CertificateImportItemType.clazz,
              classAssetCode: 'GM-01',
              detectedName: 'Guía Mayor',
              completedAt: DateTime(2024, 6, 15),
              status: CertificateImportItemStatus.approved,
            ),
          ),
        ),
      );

      expect(find.text('Registro importado'), findsOneWidget);
      expect(find.text('Guía Mayor'), findsOneWidget);
      expect(
        find.text(
            'Esta aprobación ya sustituyó la inscripción de Guía Mayor. Queda un solo registro.'),
        findsOneWidget,
      );
    });
  });
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}
