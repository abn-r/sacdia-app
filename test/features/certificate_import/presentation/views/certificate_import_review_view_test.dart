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
import 'package:sacdia_app/features/certificate_import/presentation/widgets/import_catalog_images.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/import_item_row.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/import_review_empty.dart';

import '../../support/catalog_fakes.dart';
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
  bool active = true,
  int revision = 0,
  bool suggested = false,
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
      active: active,
      revision: revision,
      honorSuggested: suggested,
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

extension on CertificateImportItem {
  CertificateImportItem copyActive(bool value) => CertificateImportItem(
        id: id,
        type: type,
        classId: classId,
        classRef: classRef,
        detectedName: detectedName,
        completedAt: completedAt,
        status: status,
        active: value,
      );
}

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
  Future<CertificateImportItem> Function(
    CertificateImportItem,
    CertificateImportItem,
  )? onUpdateItem,
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
    overrides: catalogOverrides(),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

/// [label] inside the open bottom sheet (the dock may carry the same text).
Finder _inSheet(String label) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(label),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestLocalization);

  group('rows and groups', () {
    testWidgets('summary box, then Por completar, then Listas', (tester) async {
      await _show(
        tester,
        _batch([_honor('h1'), _honor('h2', complete: false), _class('c1')]),
      );

      // "Filas listas · 2 de 3 · falta 1".
      expect(find.text('Filas listas'), findsOneWidget);
      expect(find.textContaining('2 de 3', findRichText: true), findsOneWidget);
      expect(
          find.textContaining('falta 1', findRichText: true), findsOneWidget);
      expect(find.byType(SacTweenedBar), findsOneWidget);

      // What is missing goes first, the ready rows after it.
      expect(find.text('POR COMPLETAR'), findsOneWidget);
      expect(find.text('LISTAS'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('POR COMPLETAR')).dy,
        lessThan(tester.getTopLeft(find.text('LISTAS')).dy),
      );
      // The old honors / classes split and the filters are gone.
      expect(find.textContaining('ESPECIALIDADES'), findsNothing);
      expect(find.byType(SacFilterChip), findsNothing);
      expect(find.textContaining('% OCR'), findsNothing);
      expect(find.textContaining('Catálogo'), findsNothing);
    });

    testWidgets('a row is compact: category and date, a chip, no proof link',
        (tester) async {
      await _show(
        tester,
        _batch([_honor('h1'), _class('c1'), _honor('h2', complete: false)]),
      );

      // Honor: category and date. Class: club type, investiture and date.
      expect(find.text('Salud · 12 mar 2023'), findsOneWidget);
      expect(find.text('Conquistadores · Investidura 20 nov 2022'),
          findsOneWidget);
      expect(find.byType(ImportItemRow), findsNWidgets(3));
      // Text and icon, never color alone: "Lista" x2 and "Falta" x1.
      expect(find.text('Lista'), findsNWidgets(2));
      expect(find.text('Falta'), findsOneWidget);
      // "Ver en tu comprobante" moved into the row sheet.
      expect(find.textContaining('Ver en tu comprobante'), findsNothing);
    });

    testWidgets('a class row shows its logo, a honor row its placeholder',
        (tester) async {
      await _show(tester, _batch([_honor('h1'), _class('c1')]));

      expect(find.byType(ImportClassLogo), findsOneWidget);
      expect(find.byType(ImportHonorBadge), findsOneWidget);
    });

    testWidgets('spells out what is missing in the subtitle', (tester) async {
      await _show(
        tester,
        _batch([
          _honor('h1', complete: false),
          _honor('h2', picked: false),
          _honor('h3', picked: false, complete: false),
          _class('c1', complete: false),
        ]),
      );

      expect(find.text('Salud · Falta la fecha'), findsOneWidget);
      expect(find.text('Elige la especialidad · 12 mar 2023'), findsOneWidget);
      expect(
          find.text('Elige la especialidad · Falta la fecha'), findsOneWidget);
      expect(find.text('Elige la clase · Falta la fecha'), findsOneWidget);
      expect(find.text('Falta'), findsNWidgets(4));
      expect(find.text('Lista'), findsNothing);
    });

    testWidgets('marks the honor the backend suggested', (tester) async {
      await _show(
        tester,
        _batch([
          _honor('h1', suggested: true),
          _honor('h2'),
        ]),
      );

      expect(
          find.byKey(const ValueKey('import-row-suggested')), findsOneWidget);
      expect(find.text('Sugerida'), findsOneWidget);
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
      expect(find.textContaining('Revisa la fecha'), findsOneWidget);

      expect(
        _honor('a', dateConfidence: 0.79).needsDateReview &&
            !_honor('b', dateConfidence: 0.8).needsDateReview &&
            !_honor('c').needsDateReview,
        isTrue,
      );
    });

    testWidgets('hides the date notice on a row the member already saved',
        (tester) async {
      await _show(
        tester,
        _batch([
          _honor('read', dateConfidence: 0.5),
          _honor('saved', dateConfidence: 0.5, revision: 1),
        ]),
      );
      expect(find.textContaining('Revisa la fecha'), findsOneWidget);
    });

    testWidgets('saving a row in the editor clears its date notice',
        (tester) async {
      final saved = <CertificateImportItem>[];
      await _show(
        tester,
        _batch([_honor('low', dateConfidence: 0.5)]),
        onUpdateItem: (item, _) async {
          saved.add(item);
          return item;
        },
      );
      expect(find.textContaining('Revisa la fecha'), findsOneWidget);

      await tester.tap(find.text('Primeros Auxilios').first);
      await tester.pumpAndSettle();
      // The editor still warns while the member reviews the date.
      expect(find.textContaining('Revisa la fecha'), findsNWidgets(2));

      await tester.tap(find.widgetWithText(SacButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(saved.single.revision, 1);
      expect(find.textContaining('Revisa la fecha'), findsNothing);
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

    testWidgets('the Por completar group disappears when all are ready',
        (tester) async {
      await _show(
        tester,
        _batch([_honor('h1', detected: 'Listo'), _honor('h2')]),
      );
      expect(find.text('POR COMPLETAR'), findsNothing);
      expect(find.text('LISTAS'), findsOneWidget);
      expect(find.text('Falta'), findsNothing);
    });

    testWidgets('keeps the proof as a row that opens the viewer',
        (tester) async {
      await _show(tester, _batch([_honor('h1')]), proofRoutes: true);

      // "Tu comprobante · Foto · 1 página" style row.
      expect(find.text('Tu comprobante'), findsOneWidget);
      expect(find.text('PDF · 3 páginas'), findsOneWidget);
      await tester.tap(find.text('Tu comprobante'));
      await tester.pumpAndSettle();
      expect(find.text('PROOF file-1 p1'), findsOneWidget);
    });
  });

  group('removed rows', () {
    testWidgets('are neither listed nor counted', (tester) async {
      await _show(
        tester,
        _batch([
          _honor('h1'),
          _honor('gone', active: false, complete: false),
          _class('c1'),
          _class('c-gone', complete: false).copyActive(false),
        ]),
      );

      expect(find.byType(ImportItemRow), findsNWidgets(2));
      expect(find.text('LISTAS'), findsOneWidget);
      expect(find.text('POR COMPLETAR'), findsNothing);
      expect(find.textContaining('2 de 2', findRichText: true), findsOneWidget);
      expect(find.text('Enviar a revisión'), findsOneWidget);
    });

    testWidgets('a batch with only removed rows shows the empty state',
        (tester) async {
      await _show(
        tester,
        _batch([_honor('gone', active: false)]),
      );
      expect(find.text('Enviar a revisión'), findsNothing);
      expect(find.byType(ImportReviewEmpty), findsOneWidget);
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

      expect(find.textContaining('1 de 3', findRichText: true), findsOneWidget);
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

      expect(find.textContaining('2 de 2', findRichText: true), findsOneWidget);
      await tester.tap(find.text('Enviar a revisión'));
      await tester.pumpAndSettle();
      expect(find.text('¿Enviar a tu Campo Local?'), findsOneWidget);
      expect(
        find.text('Revisará 1 especialidad y 1 clase. '
            'Mientras tanto no podrás editarlas.'),
        findsOneWidget,
      );
      expect(sent, 0);

      await tester.tap(_inSheet('Enviar a revisión'));
      await tester.pumpAndSettle();
      expect(sent, 1);
    });

    testWidgets('the send sheet counts the real rows and is not red',
        (tester) async {
      var sent = 0;
      await _show(
        tester,
        _batch([_honor('h1'), _honor('h2'), _class('c1'), _class('c2')]),
        onSubmitBatch: () async => sent++,
      );

      await tester.tap(find.text('Enviar a revisión'));
      await tester.pumpAndSettle();

      expect(find.byType(SacDialog), findsNothing);
      expect(
        find.text('Revisará 2 especialidades y 2 clases. '
            'Mientras tanto no podrás editarlas.'),
        findsOneWidget,
      );
      // The accent color: only removing something is destructive.
      final confirm = tester.widget<SacButton>(find.ancestor(
        of: _inSheet('Enviar a revisión'),
        matching: find.byType(SacButton),
      ));
      expect(confirm.variant, SacButtonVariant.primary);
      expect(find.text('Seguir revisando'), findsOneWidget);

      // "Seguir revisando" closes the sheet and sends nothing.
      await tester.tap(find.text('Seguir revisando'));
      await tester.pumpAndSettle();
      expect(find.text('¿Enviar a tu Campo Local?'), findsNothing);
      expect(sent, 0);
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
      await tester.tap(_inSheet('Enviar a revisión'));
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
        expect(find.text('Primeros Auxilios'), findsOneWidget);

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
      expect(find.text('Primeros Auxilios'), findsOneWidget);
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
    testWidgets('the row sheet opens the row file and page', (tester) async {
      await _show(
        tester,
        _batch(
          [_honor('h1', sourceFileId: 'file-2', sourcePage: 2)],
          files: const [_file1, _file2],
        ),
        proofRoutes: true,
      );

      // Not repeated on every row: it lives in the sheet of each row.
      expect(find.textContaining('Ver pág.'), findsNothing);
      await tester.tap(find.text('Primeros Auxilios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('· Ver pág. 2'));
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

      await tester.tap(find.text('Primeros Auxilios'));
      await tester.pumpAndSettle();
      expect(find.textContaining('pág.'), findsNothing);
      await tester.tap(find.text('· Ver en tu comprobante'));
      await tester.pumpAndSettle();
      expect(find.text('PROOF file-1 p1'), findsOneWidget);
    });

    testWidgets('no proof link when the batch has no file', (tester) async {
      await _show(tester, _batch([_honor('h1')], files: const []));
      expect(find.text('Tu comprobante'), findsNothing);

      await tester.tap(find.text('Primeros Auxilios'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ver en tu comprobante'), findsNothing);
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
        onUpdateItem: (item, _) async => _honor('h1', catalogName: 'Nudos'),
      );

      await tester.tap(find.text('Primeros Auxilios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Nudos'), findsOneWidget);
      expect(find.text('Lista'), findsOneWidget);
    });

    testWidgets('saving hands over the row as it was, to send only changes',
        (tester) async {
      CertificateImportItem? before;
      const ana = CertificateImportInstructorRef(
        isUser: true,
        userId: 'u1',
        displayName: 'Ana Gómez',
      );
      await _show(
        tester,
        _batch([_honor('h1', instructor: ana)]),
        onUpdateItem: (item, previous) async {
          before = previous;
          return item;
        },
      );

      await tester.tap(find.text('Primeros Auxilios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(before?.id, 'h1');
      expect(before?.instructor, ana);
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

      // A sheet, not a red dialog.
      expect(find.byType(SacDialog), findsNothing);
      await tester.tap(find.text('Conservar'));
      await tester.pumpAndSettle();
      expect(calls, 0);

      await tester.tap(find.text('Primeros Auxilios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar de la lista'));
      await tester.pumpAndSettle();
      await tester.tap(_inSheet('Quitar'));
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
      await tester.tap(_inSheet('Quitar'));
      await tester.pumpAndSettle();

      expect(find.text('Primeros Auxilios'), findsNothing);
      expect(find.textContaining('1 de 1', findRichText: true), findsOneWidget);
    });
  });

  group('reduced motion', () {
    testWidgets('rows, groups and dock work without animations',
        (tester) async {
      reduceMotion(tester);
      await _show(
        tester,
        _batch([_honor('h1'), _honor('h2', complete: false), _class('c1')]),
        settle: false,
      );

      expect(find.text('POR COMPLETAR'), findsOneWidget);
      expect(find.text('LISTAS'), findsOneWidget);
      expect(find.text('Completar 1 fila'), findsOneWidget);
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
      expect(find.text('Primeros Auxilios'), findsOneWidget);
    });
  });
}
