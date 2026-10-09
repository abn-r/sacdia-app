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
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_batch.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_file.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_item.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_payloads.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_processing_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_review_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_status_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_upload_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/certificate_import_proof_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) => EasyLocalization(
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

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(_wrap(child));
  await tester.pump();
  await tester.pump();
}

/// Opens the "add proof" sheet and taps [option] (camera, gallery or files).
Future<void> _choose(WidgetTester tester, String option) async {
  await tester.tap(find.text('Agregar comprobante'));
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
  });

  group('Certificate import routing', () {
    test(
        'declares route names for upload, processing, review and imported proof',
        () {
      expect(RouteNames.certificateImportUpload, '/certificate-import');
      expect(RouteNames.certificateImportProcessingPath('batch-1'),
          '/certificate-import/batch-1/processing');
      expect(RouteNames.certificateImportReviewPath('batch-1'),
          '/certificate-import/batch-1/review');
      expect(RouteNames.certificateImportProofPath('item-1'),
          '/certificate-import/item/item-1/proof');
      expect(routerProvider, isNotNull);
    });
  });

  group('CertificateImportUploadView', () {
    testWidgets('explains the five-page PDF limit before uploading',
        (tester) async {
      await _pump(tester, const CertificateImportUploadView());
      expect(find.textContaining('PDF de hasta 5 páginas'), findsOneWidget);
    });

    final pdfMessages = <String, String>{
      'CERTIFICATE_IMPORT_PDF_TOO_MANY_PAGES':
          'El PDF tiene más de 5 páginas. Divide el documento o extrae hasta 5 páginas y vuelve a subirlo.',
      'CERTIFICATE_IMPORT_PDF_ENCRYPTED':
          'El PDF está protegido. Quita la contraseña o la protección y vuelve a subirlo.',
      'CERTIFICATE_IMPORT_PDF_INVALID':
          'No se pudo leer el PDF. Expórtalo de nuevo como PDF y vuelve a subirlo.',
    };
    for (final entry in pdfMessages.entries) {
      testWidgets('localizes ${entry.key} without exposing technical details',
          (tester) async {
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
        await tester.tap(find.text('Subir comprobante'));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.textContaining(entry.key), findsNothing);
        expect(find.textContaining('/private/internal.pdf'), findsNothing);
        expect(find.text('comprobante.pdf'), findsOneWidget);
        final upload = tester.widget<SacButton>(
          find.widgetWithText(SacButton, 'Subir comprobante'),
        );
        expect(upload.onPressed, isNotNull);
      });
    }

    testWidgets('preserves unknown friendly failure messages', (tester) async {
      await _pump(
        tester,
        CertificateImportUploadView(
          onSubmitProofs: (_) async => throw const ServerFailure(
            message:
                'El almacenamiento no está disponible. Inténtalo más tarde.',
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
      await tester.tap(find.text('Subir comprobante'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'El almacenamiento no está disponible. Inténtalo más tarde.'),
          findsOneWidget);
    });

    testWidgets('disables upload until a proof file is selected',
        (tester) async {
      var uploadCalls = 0;
      await _pump(
        tester,
        CertificateImportUploadView(
          onSubmitProofs: (_) async => uploadCalls++,
          onPickFile: () async => const CertificateImportLocalProof(
            localPath: '/tmp/proof.jpg',
            fileName: 'comprobante.jpg',
            mimeType: 'image/jpeg',
            fileSize: 128,
          ),
        ),
      );

      expect(find.text('Subir comprobante'), findsOneWidget);
      expect(find.text('Agregar comprobante'), findsOneWidget);

      final initialUpload = tester.widget<SacButton>(
        find.widgetWithText(SacButton, 'Subir comprobante'),
      );
      expect(initialUpload.onPressed, isNull);

      await tester.tap(find.text('Subir comprobante'));
      await tester.pump();
      expect(uploadCalls, 0);

      await _choose(tester, 'Elegir archivo');
      await tester.pump();

      expect(find.text('Comprobante seleccionado'), findsOneWidget);
      expect(find.text('comprobante.jpg'), findsOneWidget);

      await tester.tap(find.text('Subir comprobante'));
      await tester.pump();

      expect(uploadCalls, 1);
    });

    testWidgets('keeps upload disabled when proof selection is cancelled',
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

      expect(find.text('Comprobante seleccionado'), findsNothing);
      var upload = tester.widget<SacButton>(
        find.widgetWithText(SacButton, 'Subir comprobante'),
      );
      expect(upload.onPressed, isNull);

      await _choose(tester, 'Tomar foto');
      await tester.pumpAndSettle();

      expect(find.text('Comprobante seleccionado'), findsNothing);
      upload = tester.widget<SacButton>(
        find.widgetWithText(SacButton, 'Subir comprobante'),
      );
      expect(upload.onPressed, isNull);

      await tester.tap(find.text('Subir comprobante'));
      await tester.pump();
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
      expect(find.text('Comprobante seleccionado'), findsOneWidget);
      expect(find.text('carrete.png'), findsOneWidget);
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
        expect(find.text('Comprobante seleccionado'), findsNothing);
        final upload = tester.widget<SacButton>(
          find.widgetWithText(SacButton, 'Subir comprobante'),
        );
        expect(upload.onPressed, isNull);
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
            find.text('El archivo supera los 10 MiB. Elige uno más liviano.'),
            findsOneWidget);
        expect(find.text('Comprobante seleccionado'), findsNothing);
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
      expect(find.text('comprobante.jpg'), findsOneWidget);

      await _choose(tester, 'Elegir archivo');
      expect(find.text('acta.pdf'), findsOneWidget);
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
      expect(find.text('comprobante.jpg'), findsOneWidget);

      next = _proof(name: 'raro.heic', mimeType: 'image/heic');
      await _choose(tester, 'Elegir de la galería');
      expect(find.text('comprobante.jpg'), findsNothing);
      expect(find.textContaining('Formato no admitido'), findsOneWidget);
    });

    testWidgets('shows three-dot loader and upload text instead of a spinner',
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
      await tester.tap(find.text('Subir comprobante'));
      await tester.pump();

      expect(find.text('Subiendo tu comprobante…'), findsOneWidget);
      expect(find.byType(SacLoadingSmall), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SacLoadingSmall),
          matching: find.byType(AnimatedBuilder),
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(SacButton, 'Subir comprobante'), findsNothing);
      final choose = tester.widget<SacButton>(
        find.widgetWithText(SacButton, 'Agregar comprobante'),
      );
      expect(choose.onPressed, isNull);

      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey('certificate-import-upload-progress')),
        ),
        matchesSemantics(
          label: 'Subiendo tu comprobante…',
          isLiveRegion: true,
        ),
      );
      semantics.dispose();

      phase.value = CertificateImportUploadPhase.reading;
      await tester.pump();
      expect(find.text('Leyendo tu comprobante…'), findsOneWidget);
      expect(find.text('Subiendo tu comprobante…'), findsNothing);

      completer.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(SacLoadingSmall), findsNothing);
      expect(find.text('Subir comprobante'), findsOneWidget);
    });

    testWidgets('uses the static dots variant under Reduced Motion',
        (tester) async {
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
      await tester.tap(find.text('Subir comprobante'));
      await tester.pump();

      expect(find.text('Subiendo tu comprobante…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SacLoadingSmall),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(SacLoadingSmall),
          matching: find.byType(DecoratedBox),
        ),
        findsNWidgets(3),
      );

      completer.complete();
      await tester.pump();
      await tester.pump();
    });
  });

  group('CertificateImportProcessingView', () {
    testWidgets('shows OCR steps and a manual fallback action', (tester) async {
      var fallbackCalls = 0;
      await _pump(
        tester,
        CertificateImportProcessingView(
          batchId: 'batch-1',
          autoStart: false,
          onManualFallback: () => fallbackCalls++,
        ),
      );

      expect(find.text('Leyendo comprobante'), findsOneWidget);
      expect(find.text('Subiendo archivo'), findsOneWidget);
      expect(find.text('Leyendo texto'), findsOneWidget);
      expect(find.text('Completar manualmente'), findsOneWidget);

      await tester.tap(find.text('Completar manualmente'));
      await tester.pump();
      expect(fallbackCalls, 1);
    });
  });

  group('CertificateImportReviewView', () {
    testWidgets(
        'renders mixed HONOR/CLASS cards, counters and disabled submit when data is missing',
        (tester) async {
      await _pump(
        tester,
        CertificateImportReviewView(
          initialBatch: _batch(),
        ),
      );

      expect(find.text('1 especialidad y 1 clase'), findsOneWidget);
      expect(find.text('HONOR'), findsOneWidget);
      expect(find.text('CLASE'), findsOneWidget);
      expect(find.text('Primeros Auxilios'), findsOneWidget);
      expect(find.text('Amigo'), findsOneWidget);

      final submit = tester.widget<SacButton>(
        find.widgetWithText(SacButton, 'Enviar a revisión'),
      );
      expect(submit.onPressed, isNull);
    });

    testWidgets('opens editor and enables submit after item correction',
        (tester) async {
      CertificateImportItem? updated;
      await _pump(
        tester,
        CertificateImportReviewView(
          initialBatch: _batch(),
          onUpdateItem: (item) async => updated = item,
        ),
      );

      await tester.tap(find.text('Corregir').first);
      await tester.pumpAndSettle();

      Finder inputWithLabel(String label) => find.descendant(
            of: find.byWidgetPredicate(
              (widget) => widget is SacTextField && widget.label == label,
            ),
            matching: find.byType(TextFormField),
          );

      await tester.enterText(inputWithLabel('ID catálogo'), '10');
      await tester.enterText(
        inputWithLabel('Fecha completada'),
        '2026-04-12',
      );
      await tester.tap(find.text('Guardar corrección'));
      await tester.pumpAndSettle();

      expect(updated?.honorId, 10);
      expect(updated?.completedAt, DateTime(2026, 4, 12));

      final submit = tester.widget<SacButton>(
        find.widgetWithText(SacButton, 'Enviar a revisión'),
      );
      expect(submit.onPressed, isNotNull);
    });
  });

  group('CertificateImportStatusView', () {
    testWidgets('shows rejected correction and resubmit affordance',
        (tester) async {
      var resubmitCalls = 0;
      await _pump(
        tester,
        CertificateImportStatusView(
          batch: _batch(rejected: true),
          onResubmitItem: (_) async => resubmitCalls++,
        ),
      );

      expect(find.text('Hay correcciones pendientes'), findsOneWidget);
      expect(
          find.text('La fecha no coincide con el comprobante'), findsOneWidget);

      await tester.tap(find.text('Corregir y reenviar').first);
      await tester.pump();
      expect(resubmitCalls, 1);
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
