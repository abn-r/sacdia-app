import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_batch.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_error_code.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_file.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_item.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_ocr_state.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_review_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/certificate_import_item_editor_sheet.dart';

import '../../support/test_app.dart';

const _file1 = CertificateImportFile(
  id: 'file-1',
  url: '',
  name: 'certificado.pdf',
  type: 'application/pdf',
  pageCount: 3,
);
const _file2 = CertificateImportFile(
  id: 'file-2',
  url: '',
  name: 'segundo.pdf',
  type: 'application/pdf',
  pageCount: 2,
);

CertificateImportItem _honor(
  String id, {
  bool complete = true,
  bool picked = true,
  String detected = 'Primeros Auxilios',
  String catalogName = 'Primeros Auxilios',
  double? dateConfidence,
  CertificateImportInstructorRef? instructor,
  String? sourceFileId,
  int? sourcePage,
}) =>
    CertificateImportItem(
      id: id,
      type: CertificateImportItemType.honor,
      honorId: picked ? 10 : null,
      honor: picked
          ? CertificateImportHonorRef(
              id: 10,
              name: catalogName,
              categoryId: 3,
              categoryName: 'Salud',
            )
          : null,
      detectedName: detected,
      completedAt: complete ? DateTime(2023, 3, 12) : null,
      fieldConfidence:
          dateConfidence == null ? null : {'date': dateConfidence, 'name': 0.9},
      instructor: instructor,
      sourceFileId: sourceFileId,
      sourcePage: sourcePage,
      status: complete
          ? CertificateImportItemStatus.ready
          : CertificateImportItemStatus.needsReview,
    );

CertificateImportItem _class(String id, {bool complete = true}) =>
    CertificateImportItem(
      id: id,
      type: CertificateImportItemType.clazz,
      classId: complete ? 3 : null,
      classRef: complete
          ? const CertificateImportClassRef(
              id: 3,
              name: 'Explorador',
              assetCode: 'CQ-02',
              clubTypeId: 1,
              clubTypeName: 'Conquistadores',
            )
          : null,
      detectedName: 'Explorador',
      completedAt: complete ? DateTime(2022, 11, 20) : null,
      status: complete
          ? CertificateImportItemStatus.ready
          : CertificateImportItemStatus.needsReview,
    );

CertificateImportBatch _batch(
  List<CertificateImportItem> items, {
  CertificateImportOcrState? ocr = CertificateImportOcrState.done,
  bool hasOcr = true,
  String? errorCode,
  List<CertificateImportFile> files = const [_file1],
}) =>
    CertificateImportBatch(
      id: 'batch-1',
      status: 'DRAFT',
      files: files,
      items: items,
      ocrState: ocr,
      hasOcrState: hasOcr,
      ocrErrorCode: errorCode,
    );

Future<void> _show(
  WidgetTester tester,
  CertificateImportBatch batch, {
  bool proofRoutes = false,
  Future<CertificateImportItem> Function(CertificateImportItem)? onUpdateItem,
  Future<void> Function(CertificateImportItem)? onRemoveItem,
  Future<void> Function()? onSubmitBatch,
  Future<CertificateImportBatch> Function()? onFetchBatch,
  Future<CertificateImportBatch> Function()? onRetryRead,
  VoidCallback? onChooseOtherFile,
  bool settle = true,
}) async {
  phoneSurface(tester);
  await tester.pumpWidget(wrapTestApp(
    CertificateImportReviewView(
      initialBatch: batch,
      onUpdateItem: onUpdateItem,
      onRemoveItem: onRemoveItem,
      onSubmitBatch: onSubmitBatch,
      onFetchBatch: onFetchBatch,
      onRetryRead: onRetryRead,
      onChooseOtherFile: onChooseOtherFile,
    ),
    proofRoutes: proofRoutes,
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestLocalization);

  group('rows and groups', () {
    testWidgets('groups honors and classes with counted headers',
        (tester) async {
      await _show(
        tester,
        _batch([_honor('h1'), _honor('h2'), _class('c1')]),
      );

      expect(find.text('2 especialidades y 1 clase'), findsOneWidget);
      expect(find.text('ESPECIALIDADES · 2'), findsOneWidget);
      expect(find.text('CLASES · 1'), findsOneWidget);
      // Catalog name, category and club type; never an id or a percentage.
      expect(find.text('Salud'), findsNWidgets(2));
      expect(find.text('Explorador'), findsOneWidget);
      expect(find.text('Conquistadores'), findsOneWidget);
      expect(find.textContaining('% OCR'), findsNothing);
      expect(find.textContaining('Catálogo'), findsNothing);
      expect(find.textContaining('Amigo y Explorador'), findsNothing);
      // The filter chips carry their counts.
      final chips =
          tester.widgetList<SacFilterChip>(find.byType(SacFilterChip));
      expect(chips.map((chip) => (chip.label, chip.count)),
          [('Todas', 3), ('Listas', 3)]);
    });

    testWidgets('spells out what is missing in the badge', (tester) async {
      await _show(
        tester,
        _batch([
          _honor('h1', complete: false),
          _honor('h2', picked: false),
          _honor('h3', picked: false, complete: false),
          _class('c1', complete: false),
        ]),
      );

      expect(find.text('Falta la fecha'), findsOneWidget);
      expect(find.text('Falta elegir la especialidad'), findsOneWidget);
      // Neither the honor h3 nor the class has its selection or its date.
      expect(find.text('Faltan 2 datos'), findsNWidgets(2));
      expect(find.text('Lista'), findsNothing);
    });

    testWidgets('shows what was read only when it differs from the catalog',
        (tester) async {
      await _show(
        tester,
        _batch([
          _honor('h1', detected: 'Primeros Auxilos basico'),
          _honor('h2', detected: 'primeros auxilios'),
        ]),
      );

      expect(find.text('Leído: «Primeros Auxilos basico»'), findsOneWidget);
      expect(find.textContaining('Leído: «primeros'), findsNothing);
    });

    testWidgets('asks to check the date only below the 0.8 threshold',
        (tester) async {
      await _show(
        tester,
        _batch([
          _honor('low', dateConfidence: 0.79),
          _honor('edge', dateConfidence: 0.8),
          _honor('none'),
        ]),
      );
      expect(find.text('Revisa la fecha'), findsOneWidget);

      expect(
        _honor('a', dateConfidence: 0.79).needsDateReview &&
            !_honor('b', dateConfidence: 0.8).needsDateReview &&
            !_honor('c').needsDateReview,
        isTrue,
      );
    });

    testWidgets('shows the instructor next to the date', (tester) async {
      await _show(
        tester,
        _batch([
          _honor(
            'h1',
            instructor: const CertificateImportInstructorRef(
              isUser: true,
              displayName: 'Ana Gómez',
            ),
          ),
        ]),
      );
      expect(find.text('12/03/2023 · Ana Gómez'), findsOneWidget);
    });

    testWidgets('tolerates rows without the new keys (R6)', (tester) async {
      await _show(
        tester,
        _batch([
          const CertificateImportItem(
            id: 'old',
            type: CertificateImportItemType.honor,
            honorId: 10,
            detectedName: 'Nudos',
            status: CertificateImportItemStatus.needsReview,
          ),
        ], hasOcr: false, ocr: null),
      );
      expect(find.text('Nudos'), findsOneWidget);
      expect(find.text('Falta la fecha'), findsOneWidget);
    });

    testWidgets('the Por completar chip filters and hides when all are ready',
        (tester) async {
      await _show(
        tester,
        _batch(
            [_honor('h1', detected: 'Listo'), _honor('h2', complete: false)]),
      );
      await tester.tap(find.text('Por completar'));
      await tester.pumpAndSettle();
      expect(find.text('Falta la fecha'), findsOneWidget);
      expect(find.text('Lista'), findsNothing);
    });
  });

  group('dock', () {
    testWidgets('completes rows first, then sends', (tester) async {
      await _show(
        tester,
        _batch([
          _honor('h1'),
          _honor('h2', complete: false),
          _class('c1', complete: false),
        ]),
      );

      expect(find.text('1 de 3 listas'), findsOneWidget);
      expect(find.byType(SacTweenedBar), findsOneWidget);
      expect(find.text('Completar 2 filas'), findsOneWidget);
      expect(find.text('Enviar a revisión'), findsNothing);

      // It opens the editor of the first incomplete row.
      await tester.tap(find.text('Completar 2 filas'));
      await tester.pumpAndSettle();
      final editor = tester.widget<CertificateImportItemEditorSheet>(
        find.byType(CertificateImportItemEditorSheet),
      );
      expect(editor.item.id, 'h2');
    });

    testWidgets('says "Completar 1 fila" in the singular', (tester) async {
      await _show(
          tester, _batch([_honor('h1'), _honor('h2', complete: false)]));
      expect(find.text('Completar 1 fila'), findsOneWidget);
    });

    testWidgets('offers to send when everything is ready and confirms first',
        (tester) async {
      var sent = 0;
      await _show(
        tester,
        _batch([_honor('h1'), _class('c1')]),
        onSubmitBatch: () async => sent++,
      );

      expect(find.text('2 de 2 listas'), findsOneWidget);
      await tester.tap(find.text('Enviar a revisión'));
      await tester.pumpAndSettle();
      expect(find.text('¿Enviar a revisión?'), findsOneWidget);
      expect(
        find.text('Tu Campo Local revisará 1 especialidad y 1 clase. '
            'Mientras tanto no podrás editarlas.'),
        findsOneWidget,
      );
      expect(sent, 0);

      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();
      expect(sent, 1);
    });

    testWidgets('a failed send shows a banner in the dock and can retry',
        (tester) async {
      var calls = 0;
      await _show(
        tester,
        _batch([_honor('h1')]),
        onSubmitBatch: () async {
          calls++;
          throw const ServerFailure(message: 'stack /srv/api', code: 500);
        },
      );

      await tester.tap(find.text('Enviar a revisión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos enviarlo. Revisa tu conexión e inténtalo de '
            'nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining('/srv/api'), findsNothing);
      final button = tester.widget<SacButton>(
        find.widgetWithText(SacButton, 'Enviar a revisión'),
      );
      expect(button.isLoading, isFalse);
      expect(button.onPressed, isNotNull);
      expect(calls, 1);
    });

    testWidgets('no dock without rows', (tester) async {
      await _show(
          tester, _batch(const [], ocr: CertificateImportOcrState.empty));
      expect(find.text('Enviar a revisión'), findsNothing);
      expect(find.byType(SacTweenedBar), findsNothing);
    });
  });

  group('reading states (F)', () {
    testWidgets('empty: nothing found, add by hand', (tester) async {
      await _show(
        tester,
        _batch(const [], ocr: CertificateImportOcrState.empty),
      );
      expect(
          find.text('No encontramos especialidades ni clases'), findsOneWidget);
      expect(find.text('Agregar especialidad o clase'), findsOneWidget);
      expect(find.text('Reintentar lectura'), findsNothing);
    });

    testWidgets('no ocr_state key behaves as empty (R6)', (tester) async {
      await _show(tester, _batch(const [], hasOcr: false, ocr: null));
      expect(
          find.text('No encontramos especialidades ni clases'), findsOneWidget);
    });

    testWidgets('explicit null ocr_state: manual batch', (tester) async {
      await _show(tester, _batch(const [], ocr: null));
      expect(find.text('No hay filas todavía'), findsOneWidget);
    });

    for (final state in [
      CertificateImportOcrState.pending,
      CertificateImportOcrState.running,
    ]) {
      testWidgets('${state.name}: keeps reading and refreshes by itself',
          (tester) async {
        var fetches = 0;
        await _show(
          tester,
          _batch(const [], ocr: state),
          settle: false,
          onFetchBatch: () async {
            fetches++;
            return _batch([_honor('h1')]);
          },
        );
        expect(find.text('Seguimos leyendo tu comprobante'), findsOneWidget);
        expect(fetches, 0);

        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(fetches, 1);
        expect(find.text('Seguimos leyendo tu comprobante'), findsNothing);
        expect(find.text('1 especialidad'), findsOneWidget);

        // Polling stops once the reading is over.
        await tester.pump(const Duration(seconds: 7));
        expect(fetches, 1);
      });
    }

    testWidgets('failed without a code: retry the reading', (tester) async {
      var retries = 0;
      await _show(
        tester,
        _batch(const [], ocr: CertificateImportOcrState.failed),
        onRetryRead: () async {
          retries++;
          return _batch([_honor('h1')]);
        },
      );
      expect(find.text('No pudimos leer tu comprobante'), findsOneWidget);

      await tester.tap(find.text('Reintentar lectura'));
      await tester.pumpAndSettle();
      expect(retries, 1);
      expect(find.text('1 especialidad'), findsOneWidget);
    });

    testWidgets('failed with a protected PDF: no useless retry',
        (tester) async {
      var chose = 0;
      await _show(
        tester,
        _batch(
          const [],
          ocr: CertificateImportOcrState.failed,
          errorCode: CertificateImportErrorCode.pdfEncrypted,
        ),
        onRetryRead: () async => _batch(const []),
        onChooseOtherFile: () => chose++,
      );
      expect(find.text('El PDF está protegido'), findsOneWidget);
      expect(find.text('Reintentar lectura'), findsNothing);
      expect(find.textContaining('CERTIFICATE_IMPORT'), findsNothing);

      await tester.tap(find.text('Elegir otro archivo'));
      expect(chose, 1);
      // Adding by hand stays available.
      expect(find.text('Agregar especialidad o clase'), findsOneWidget);
    });

    testWidgets('failed because the reading is off: add by hand only',
        (tester) async {
      await _show(
        tester,
        _batch(
          const [],
          ocr: CertificateImportOcrState.failed,
          errorCode: CertificateImportErrorCode.ocrUnavailable,
        ),
        onRetryRead: () async => _batch(const []),
      );
      expect(find.text('La lectura automática no está disponible ahora'),
          findsOneWidget);
      expect(find.text('Reintentar lectura'), findsNothing);
      expect(find.widgetWithText(SacButton, 'Agregar especialidad o clase'),
          findsOneWidget);
    });

    testWidgets('an unknown error code is never printed', (tester) async {
      await _show(
        tester,
        _batch(const [],
            ocr: CertificateImportOcrState.failed, errorCode: 'MADE_UP'),
      );
      expect(find.textContaining('MADE_UP'), findsNothing);
      expect(find.text('No pudimos leer tu comprobante'), findsOneWidget);
    });
  });

  group('see in the proof', () {
    testWidgets('opens the row file and page', (tester) async {
      await _show(
        tester,
        _batch(
          [_honor('h1', sourceFileId: 'file-2', sourcePage: 2)],
          files: const [_file1, _file2],
        ),
        proofRoutes: true,
      );

      await tester.tap(find.text('Ver en tu comprobante · pág. 2'));
      await tester.pumpAndSettle();
      expect(find.text('PROOF file-2 p2'), findsOneWidget);
    });

    testWidgets('falls back to the first file on page 1', (tester) async {
      await _show(
        tester,
        _batch(
          [_honor('h1', sourceFileId: 'gone', sourcePage: 2)],
          files: const [_file1, _file2],
        ),
        proofRoutes: true,
      );

      expect(find.textContaining('pág.'), findsNothing);
      await tester.tap(find.text('Ver en tu comprobante'));
      await tester.pumpAndSettle();
      expect(find.text('PROOF file-1 p1'), findsOneWidget);
    });

    testWidgets('no button when the batch has no file', (tester) async {
      await _show(tester, _batch([_honor('h1')], files: const []));
      expect(find.text('Ver en tu comprobante'), findsNothing);
    });
  });

  group('editing and removing', () {
    testWidgets('tapping a row opens its editor', (tester) async {
      await _show(tester, _batch([_honor('h1', complete: false)]));

      await tester.tap(find.text('Primeros Auxilios'));
      await tester.pumpAndSettle();
      expect(find.byType(CertificateImportItemEditorSheet), findsOneWidget);
    });

    testWidgets('saving shows the row as the API returned it', (tester) async {
      await _show(
        tester,
        _batch([_honor('h1', complete: false, picked: false)]),
        onUpdateItem: (item) async => _honor('h1', catalogName: 'Nudos'),
      );

      await tester.tap(find.text('Primeros Auxilios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Nudos'), findsOneWidget);
      expect(find.text('Lista'), findsOneWidget);
    });

    testWidgets('asks before removing and keeps the row when it fails',
        (tester) async {
      var calls = 0;
      await _show(
        tester,
        _batch([_honor('h1')]),
        onRemoveItem: (_) async {
          calls++;
          throw const ServerFailure(message: 'x', errorCode: 'NETWORK');
        },
      );

      await tester.tap(find.text('Primeros Auxilios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar de la lista'));
      await tester.pumpAndSettle();
      expect(find.text('¿Quitar esta especialidad?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(calls, 0);

      await tester.tap(find.text('Primeros Auxilios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar de la lista'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(SacDialog),
        matching: find.text('Quitar'),
      ));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.text('Primeros Auxilios'), findsOneWidget);
      expect(find.text('Revisa tu conexión a internet e inténtalo de nuevo.'),
          findsOneWidget);
    });

    testWidgets('a removed row leaves the list', (tester) async {
      await _show(
        tester,
        _batch([_honor('h1'), _class('c1')]),
        onRemoveItem: (_) async {},
      );
      await tester.tap(find.text('Primeros Auxilios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar de la lista'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(SacDialog),
        matching: find.text('Quitar'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Primeros Auxilios'), findsNothing);
      expect(find.text('1 clase'), findsOneWidget);
    });
  });

  group('reduced motion', () {
    testWidgets('rows, filters and dock work without animations',
        (tester) async {
      reduceMotion(tester);
      await _show(
        tester,
        _batch([_honor('h1'), _honor('h2', complete: false), _class('c1')]),
        settle: false,
      );

      expect(find.text('ESPECIALIDADES · 2'), findsOneWidget);
      expect(find.text('Completar 1 fila'), findsOneWidget);
      await tester.tap(find.text('Por completar'));
      await tester.pump();
      expect(find.text('Falta la fecha'), findsOneWidget);
      expect(find.text('Lista'), findsNothing);
    });

    testWidgets('the reading state shows static dots and still refreshes',
        (tester) async {
      reduceMotion(tester);
      var fetches = 0;
      await _show(
        tester,
        _batch(const [], ocr: CertificateImportOcrState.running),
        settle: false,
        onFetchBatch: () async {
          fetches++;
          return _batch([_honor('h1')]);
        },
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(fetches, 1);
      expect(find.text('1 especialidad'), findsOneWidget);
    });
  });
}
