import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/consent/consent_evidence.dart';
import 'package:sacdia_app/core/consent/consent_evidence_uploader.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

import '../../features/family/family_test_harness.dart';

const _receipt = ConsentEvidenceReceipt(
  evidenceId: 'ev-1',
  contentType: 'application/pdf',
  sizeBytes: 2048,
);

ConsentEvidencePicker _picker({
  String name = 'ficha.pdf',
  int size = 2048,
  bool failing = false,
}) =>
    ConsentEvidencePicker(
      pickPdf: () async {
        if (failing) throw StateError('permission denied');
        return (path: '/tmp/$name', name: name, size: size);
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  final uploads = <ConsentEvidenceLocalFile>[];
  final uploaded = <ConsentEvidenceReceipt>[];
  final pending = <bool>[];
  final uploading = <bool>[];

  setUp(() {
    uploads.clear();
    uploaded.clear();
    pending.clear();
    uploading.clear();
  });

  Future<void> pump(
    WidgetTester tester, {
    required ConsentUploadCallback onUpload,
    ConsentEvidencePicker? picker,
    bool hasExisting = false,
    bool enabled = true,
    bool autoUpload = false,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        assetLoader: const FileAssetLoader(),
        fallbackLocale: const Locale('es'),
        startLocale: const Locale('es'),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(0.5),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ConsentEvidenceUploader(
                  picker: picker ?? _picker(),
                  hasExisting: hasExisting,
                  enabled: enabled,
                  autoUpload: autoUpload,
                  onUploadingChanged: uploading.add,
                  onUpload: onUpload,
                  onUploaded: uploaded.add,
                  onPendingChanged: pending.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> choosePdf(WidgetTester tester, {String label = ''}) async {
    await tester.tap(find.text(label.isEmpty ? 'Subir ficha firmada' : label));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir un PDF'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers the three sources in a sheet', (tester) async {
    await pump(tester, onUpload: (_) async => const Right(_receipt));

    await tester.tap(find.text('Subir ficha firmada'));
    await tester.pumpAndSettle();

    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Elegir de la galería'), findsOneWidget);
    expect(find.text('Elegir un PDF'), findsOneWidget);
  });

  testWidgets('says "Reemplazar" when a form is already there', (tester) async {
    await pump(
      tester,
      hasExisting: true,
      onUpload: (_) async => const Right(_receipt),
    );
    expect(find.text('Reemplazar ficha'), findsOneWidget);
    expect(find.text('Subir ficha firmada'), findsNothing);
  });

  testWidgets('picking a file previews it and reports it as pending',
      (tester) async {
    await pump(tester, onUpload: (_) async => const Right(_receipt));

    await choosePdf(tester);

    expect(find.text('ficha.pdf'), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);
    expect(pending, [true]);
    expect(uploads, isEmpty, reason: 'picking never uploads by itself');
  });

  testWidgets('uploading calls the callback once and clears the pending file',
      (tester) async {
    await pump(tester, onUpload: (file) async {
      uploads.add(file);
      return const Right(_receipt);
    });
    await choosePdf(tester);

    await tester.tap(find.text('Subir'));
    await tester.pumpAndSettle();

    expect(uploads.single.name, 'ficha.pdf');
    expect(uploaded, [_receipt]);
    expect(pending, [true, false]);
    expect(find.text('Subir ficha firmada'), findsOneWidget,
        reason: 'back to the idle state');
  });

  testWidgets('a failed upload shows the reason and retries the same file',
      (tester) async {
    var attempts = 0;
    await pump(tester, onUpload: (file) async {
      attempts++;
      if (attempts == 1) {
        return const Left(
          ConnectionFailure(message: 'offline'),
        );
      }
      return const Right(_receipt);
    });
    await choosePdf(tester);

    await tester.tap(find.text('Subir'));
    await tester.pumpAndSettle();

    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('ficha.pdf'), findsOneWidget, reason: 'file is kept');
    expect(uploaded, isEmpty);
    expect(pending, [true], reason: 'still pending, never cleared');

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(uploaded, [_receipt]);
  });

  testWidgets('503 shows the "not available yet" message', (tester) async {
    await pump(tester, onUpload: (_) async {
      return const Left(
        ServerFailure(
          message: 'x',
          code: 503,
          errorCode: 'GUARDIANSHIP_EVIDENCE_UNAVAILABLE',
        ),
      );
    });
    await choosePdf(tester);

    await tester.tap(find.text('Subir'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Las fichas de consentimiento aún no están disponibles. Inténtalo más tarde.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a 413 from the server says the file is too large',
      (tester) async {
    await pump(tester, onUpload: (_) async {
      return const Left(ServerFailure(message: 'x', code: 413));
    });
    await choosePdf(tester);

    await tester.tap(find.text('Subir'));
    await tester.pumpAndSettle();

    expect(find.text('El archivo supera el máximo de 10 MB.'), findsOneWidget);
  });

  testWidgets('a 12 MB file is rejected client-side with no upload',
      (tester) async {
    await pump(
      tester,
      picker: _picker(name: 'grande.pdf', size: 12 * 1024 * 1024),
      onUpload: (file) async {
        uploads.add(file);
        return const Right(_receipt);
      },
    );
    await choosePdf(tester);

    expect(
      find.text('El archivo supera los 10 MB. Elige uno más pequeño.'),
      findsOneWidget,
    );
    final button = tester.widget<SacButton>(
      find.byWidgetPredicate((w) => w is SacButton && w.text == 'Subir'),
    );
    expect(button.onPressed, isNull);
    expect(uploads, isEmpty);
  });

  testWidgets('a picker failure is explained instead of crashing',
      (tester) async {
    await pump(
      tester,
      picker: _picker(failing: true),
      onUpload: (_) async => const Right(_receipt),
    );

    await choosePdf(tester);

    expect(
      find.text(
        'No se pudo abrir el archivo. Revisa los permisos e intenta de nuevo.',
      ),
      findsOneWidget,
    );
    expect(pending, isEmpty);
  });

  testWidgets('change lets the user pick another file', (tester) async {
    await pump(tester, onUpload: (_) async => const Right(_receipt));
    await choosePdf(tester);

    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();
    expect(find.text('Elegir un PDF'), findsOneWidget);
    await tester.tap(find.text('Elegir un PDF'));
    await tester.pumpAndSettle();

    expect(find.text('ficha.pdf'), findsOneWidget);
  });

  testWidgets('disabled blocks picking', (tester) async {
    await pump(
      tester,
      enabled: false,
      onUpload: (_) async => const Right(_receipt),
    );
    await tester.tap(find.text('Subir ficha firmada'));
    await tester.pumpAndSettle();
    expect(find.text('Elegir un PDF'), findsNothing);
  });

  testWidgets('leaving while uploading does not throw or call back',
      (tester) async {
    final gate = Completer<Either<Failure, ConsentEvidenceReceipt>>();
    await pump(tester, onUpload: (file) {
      uploads.add(file);
      return gate.future;
    });
    await choosePdf(tester);
    await tester.tap(find.text('Subir'));
    await tester.pump();

    // La pantalla se desmonta con la subida en vuelo.
    await tester.pumpWidget(const SizedBox());
    gate.complete(const Right(_receipt));
    await tester.pump();

    expect(uploaded, isEmpty);
    expect(tester.takeException(), isNull);
  });

  group('autoUpload', () {
    testWidgets('uploads once right after picking, with no second tap',
        (tester) async {
      await pump(
        tester,
        autoUpload: true,
        onUpload: (file) async {
          uploads.add(file);
          return const Right(_receipt);
        },
      );

      await choosePdf(tester);
      await tester.pumpAndSettle();

      expect(uploads, hasLength(1));
      expect(uploads.single.name, 'ficha.pdf');
      expect(uploaded, [_receipt]);
      expect(uploading, [true, false]);
      expect(pending, [true, false]);
    });

    testWidgets('a failure keeps the file pending and offers a retry',
        (tester) async {
      var attempts = 0;
      await pump(
        tester,
        autoUpload: true,
        onUpload: (file) async {
          attempts++;
          if (attempts == 1) {
            return const Left(ServerFailure(message: 'x', code: 500));
          }
          return const Right(_receipt);
        },
      );

      await choosePdf(tester);
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(find.text('ficha.pdf'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(pending, [true]);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(uploaded, [_receipt]);
      expect(pending, [true, false]);
    });

    testWidgets('an invalid file is NOT sent and stays pending',
        (tester) async {
      await pump(
        tester,
        autoUpload: true,
        picker: _picker(size: consentEvidenceMaxBytes + 1),
        onUpload: (file) async {
          uploads.add(file);
          return const Right(_receipt);
        },
      );

      await choosePdf(tester);
      await tester.pumpAndSettle();

      expect(uploads, isEmpty);
      expect(uploading, isEmpty);
      expect(pending, [true]);
    });

    testWidgets('without the flag nothing is sent until "Subir"',
        (tester) async {
      await pump(
        tester,
        onUpload: (file) async {
          uploads.add(file);
          return const Right(_receipt);
        },
      );

      await choosePdf(tester);
      await tester.pumpAndSettle();

      expect(uploads, isEmpty);
      expect(uploading, isEmpty);
    });
  });

  group('file label', () {
    const generated = 'image_picker_E1F03742-B4FC-4A4B-9E0D-8F0A1B2C3D4E';

    testWidgets('a made-up photo name shows "Ficha firmada · Foto"',
        (tester) async {
      final dir = Directory.systemTemp.createTempSync('consent_label');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/$generated.jpg')
        ..writeAsBytesSync(Uint8List.fromList(List.filled(2048, 1)));
      await pump(
        tester,
        picker: ConsentEvidencePicker(
          pickImage: (_) async => XFile(file.path, name: '$generated.jpg'),
        ),
        onUpload: (_) async => const Right(_receipt),
      );

      await tester.tap(find.text('Subir ficha firmada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      // `XFile.length()` es E/S real: no avanza con el reloj falso.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      expect(find.text('Ficha firmada · Foto'), findsOneWidget);
      expect(find.textContaining('image_picker_'), findsNothing);
    });

    testWidgets('a made-up PDF name shows "Ficha firmada · PDF"',
        (tester) async {
      await pump(
        tester,
        picker: _picker(name: '$generated.pdf'),
        onUpload: (_) async => const Right(_receipt),
      );

      await choosePdf(tester);

      expect(find.text('Ficha firmada · PDF'), findsOneWidget);
      expect(find.textContaining('image_picker_'), findsNothing);
    });

    testWidgets('a real file name is kept', (tester) async {
      await pump(tester, onUpload: (_) async => const Right(_receipt));

      await choosePdf(tester);

      expect(find.text('ficha.pdf'), findsOneWidget);
      expect(find.text('Ficha firmada · PDF'), findsNothing);
    });
  });
}
