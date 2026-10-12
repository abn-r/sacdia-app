import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/constants/certificate_dates.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/instructor_picker.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_picker_field.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_item.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/certificate_import_item_editor_sheet.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/detected_text_quote.dart';

import '../../support/catalog_fakes.dart';
import '../../support/test_app.dart';

/// Fixed "today" so date rules do not depend on the day the suite runs.
final _today = DateTime(2026, 10, 12);

CertificateImportItem _honorRow({
  int? honorId,
  CertificateImportHonorRef? honor,
  DateTime? completedAt,
  DateTime? detectedDate,
  String detected = 'Primeros Auxilos basico',
  double? dateConfidence,
  CertificateImportItemStatus status = CertificateImportItemStatus.needsReview,
}) =>
    CertificateImportItem(
      id: 'row-1',
      batchId: 'batch-1',
      type: CertificateImportItemType.honor,
      honorId: honorId,
      honor: honor,
      detectedName: detected,
      detectedDate: detectedDate,
      completedAt: completedAt,
      fieldConfidence: dateConfidence == null ? null : {'date': dateConfidence},
      status: status,
    );

const _firstAidRef = CertificateImportHonorRef(
  id: 10,
  name: 'Primeros Auxilios',
  categoryId: 3,
  categoryName: 'Salud',
);

CertificateImportItem _classRow({
  int? classId,
  CertificateImportClassRef? classRef,
  DateTime? completedAt,
}) =>
    CertificateImportItem(
      id: 'row-2',
      batchId: 'batch-1',
      type: CertificateImportItemType.clazz,
      classId: classId,
      classRef: classRef,
      detectedName: 'Explorador',
      completedAt: completedAt,
      status: CertificateImportItemStatus.needsReview,
    );

class _Saved {
  CertificateImportItem? item;
  int calls = 0;
  Object? failWith;

  Future<void> call(CertificateImportItem value) async {
    calls++;
    if (failWith != null) throw failWith!;
    item = value;
  }
}

/// Opens the editor in a real bottom sheet from a button.
Future<void> _open(
  WidgetTester tester,
  CertificateImportItem item,
  _Saved saved, {
  FakeGetHonors? honors,
  bool isNew = false,
  VoidCallback? onRemove,
  VoidCallback? onViewProof,
  int? proofPage,
}) async {
  phoneSurface(tester, height: 2400);
  await tester.pumpWidget(wrapTestApp(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showSacSheetForTest(
              context,
              CertificateImportItemEditorSheet(
                item: item,
                onSave: saved.call,
                onRemove: onRemove,
                onViewProof: onViewProof,
                proofPage: proofPage,
                isNew: isNew,
                clock: () => _today,
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
    overrides: catalogOverrides(honors: honors),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> showSacSheetForTest(BuildContext context, Widget sheet) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => sheet,
  );
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(SacButton, 'Guardar'));
  await tester.tap(find.widgetWithText(SacButton, 'Guardar'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestLocalization);

  group('honor form', () {
    testWidgets('reads as a quote, chooses from the catalog, has no ID field',
        (tester) async {
      await _open(
        tester,
        _honorRow(honorId: 10, honor: _firstAidRef),
        _Saved(),
        onViewProof: () {},
        proofPage: 2,
      );

      expect(find.byType(DetectedTextQuote), findsOneWidget);
      expect(find.text('«Primeros Auxilos basico»'), findsOneWidget);
      expect(find.text('Leído en tu comprobante'), findsOneWidget);
      expect(find.text('Ver en tu comprobante · pág. 2'), findsOneWidget);
      // The OCR proposal waits for confirmation.
      expect(find.text('Sugerida'), findsOneWidget);
      expect(find.text('Primeros Auxilios'), findsOneWidget);
      expect(find.text('Fecha en que la completaste'), findsOneWidget);
      // Nothing to type: no catalog id, no free date.
      expect(find.text('ID catálogo'), findsNothing);
      expect(find.byType(SacTextField), findsNothing);
      expect(find.text('Corregir especialidad'), findsOneWidget);
    });

    testWidgets('"Corregir texto" turns the quote into a text field',
        (tester) async {
      await _open(tester, _honorRow(), _Saved());
      await tester.tap(find.text('Corregir texto'));
      await tester.pumpAndSettle();
      expect(find.byType(DetectedTextQuote), findsNothing);
      expect(find.byType(SacTextField), findsOneWidget);
    });

    testWidgets('hides the category filter for a honor without category',
        (tester) async {
      await _open(
        tester,
        _honorRow(
          honorId: 10,
          honor: const CertificateImportHonorRef(id: 10, name: 'Nudos'),
        ),
        _Saved(),
      );
      expect(find.text('Categoría'), findsNothing);
    });

    testWidgets('lists what is missing above the always-enabled save button',
        (tester) async {
      await _open(tester, _honorRow(), _Saved());
      expect(find.text('Falta: especialidad, fecha'), findsOneWidget);
      final save =
          tester.widget<SacButton>(find.widgetWithText(SacButton, 'Guardar'));
      expect(save.onPressed, isNotNull);
    });

    testWidgets('a draft saves as needs-review with no catalog ids',
        (tester) async {
      final saved = _Saved();
      await _open(tester, _honorRow(), saved);
      await _save(tester);

      expect(saved.item!.status, CertificateImportItemStatus.needsReview);
      expect(saved.item!.honorId, isNull);
      expect(saved.item!.classId, isNull);
      // The sheet closes after a successful save.
      expect(find.byType(CertificateImportItemEditorSheet), findsNothing);
    });

    testWidgets('keeps the id of a proposal the API sent without names (R6)',
        (tester) async {
      final saved = _Saved();
      await _open(
        tester,
        _honorRow(honorId: 10, completedAt: DateTime(2023, 3, 12)),
        saved,
      );
      await _save(tester);
      expect(saved.item!.honorId, 10);
      expect(saved.item!.status, CertificateImportItemStatus.ready);
    });

    testWidgets('prefills a readable date and flags a doubtful one',
        (tester) async {
      await _open(
        tester,
        _honorRow(detectedDate: DateTime(2023, 3, 12), dateConfidence: 0.7),
        _Saved(),
      );
      expect(find.text('Revisa la fecha'), findsOneWidget);
      expect(find.textContaining('12 mar 2023'), findsOneWidget);
    });

    testWidgets('an unreadable date arrives empty with an explanation',
        (tester) async {
      await _open(
        tester,
        _honorRow(detectedDate: DateTime(1925, 1, 1), dateConfidence: 0),
        _Saved(),
      );
      expect(
        find.text('Revisa la fecha. Lo que leímos no es una fecha válida'),
        findsOneWidget,
      );
      expect(find.textContaining('1925'), findsNothing);
    });
  });

  group('date rule in the form', () {
    for (final (label, date, message) in [
      (
        '1959-12-31 is rejected',
        DateTime(1959, 12, 31),
        'La fecha no puede ser anterior a 1960',
      ),
      (
        'tomorrow is rejected',
        DateTime(2026, 10, 13),
        'La fecha no puede ser futura',
      ),
    ]) {
      testWidgets(label, (tester) async {
        final saved = _Saved();
        await _open(
          tester,
          _honorRow(honorId: 10, honor: _firstAidRef, completedAt: date),
          saved,
        );
        await _save(tester);

        expect(find.text(message), findsOneWidget);
        expect(saved.calls, 0);
        expect(find.byType(CertificateImportItemEditorSheet), findsOneWidget);
      });
    }

    for (final (label, date) in [
      ('1960-01-01 is accepted', DateTime(1960, 1, 1)),
      ('today is accepted', DateTime(2026, 10, 12)),
    ]) {
      testWidgets(label, (tester) async {
        final saved = _Saved();
        await _open(
          tester,
          _honorRow(honorId: 10, honor: _firstAidRef, completedAt: date),
          saved,
        );
        await _save(tester);
        expect(saved.calls, 1);
        expect(saved.item!.completedAt, date);
        expect(saved.item!.status, CertificateImportItemStatus.ready);
      });
    }

    testWidgets('the picker runs from 1960-01-01 to today', (tester) async {
      await _open(tester, _honorRow(), _Saved());
      await tester.tap(find.text('Seleccionar fecha'));
      await tester.pumpAndSettle();

      final calendar =
          tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
      expect(calendar.firstDate, kMinCertificateDate);
      expect(calendar.lastDate, DateTime(2026, 10, 12));
    });

    testWidgets('a picked date clears the error and the hint', (tester) async {
      final saved = _Saved();
      await _open(
        tester,
        _honorRow(honorId: 10, honor: _firstAidRef, dateConfidence: 0.2),
        saved,
      );
      await tester.tap(find.text('Seleccionar fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();
      await _save(tester);

      expect(saved.item!.completedAt, DateTime(2026, 10, 12));
      expect(saved.item!.status, CertificateImportItemStatus.ready);
    });
  });

  group('class form', () {
    testWidgets('club type chips, then the classes of that type',
        (tester) async {
      final saved = _Saved();
      await _open(
        tester,
        _classRow(completedAt: DateTime(2022, 11, 20)),
        saved,
      );

      expect(find.text('Corregir clase'), findsOneWidget);
      expect(find.text('Fecha de investidura'), findsOneWidget);
      expect(find.text('Elige primero el tipo de club.'), findsOneWidget);

      await tester.tap(find.text('Conquistadores'));
      await tester.pumpAndSettle();
      expect(find.text('Amigo'), findsOneWidget);
      expect(find.text('Explorador'), findsWidgets);

      await tester.tap(find.text('Amigo'));
      await tester.pumpAndSettle();
      await _save(tester);

      expect(saved.item!.classId, 1);
      expect(saved.item!.classRef?.clubTypeId, 1);
      expect(saved.item!.classRef?.clubTypeName, 'Conquistadores');
      expect(saved.item!.honorId, isNull);
      expect(saved.item!.status, CertificateImportItemStatus.ready);
    });

    testWidgets('order hint names the previous class, only when there is one',
        (tester) async {
      await _open(
        tester,
        _classRow(completedAt: DateTime(2022, 11, 20)),
        _Saved(),
      );
      await tester.tap(find.text('Conquistadores'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Amigo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('aunque no tengas'), findsNothing);

      await tester.tap(find.text('Explorador').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Puedes acreditar Explorador aunque no tengas Amigo '
            'registrado.'),
        findsOneWidget,
      );
    });

    testWidgets('an institutional class explains it creates no enrollment',
        (tester) async {
      await _open(
        tester,
        _classRow(completedAt: DateTime(2022, 11, 20)),
        _Saved(),
      );
      await tester.tap(find.text('Conquistadores'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guía Mayor Instructor'));
      await tester.pumpAndSettle();
      expect(
        find.text('Revisión institucional: aprobar no crea inscripción.'),
        findsOneWidget,
      );
      expect(find.textContaining('aunque no tengas'), findsNothing);
    });

    testWidgets('changing the club type clears the class', (tester) async {
      await _open(
        tester,
        _classRow(
          classId: 3,
          classRef: const CertificateImportClassRef(
            id: 3,
            name: 'Explorador',
            clubTypeId: 1,
            clubTypeName: 'Conquistadores',
          ),
          completedAt: DateTime(2022, 11, 20),
        ),
        _Saved(),
      );
      expect(find.text('Sugerida'), findsOneWidget);

      await tester.tap(find.text('Aventureros'));
      await tester.pumpAndSettle();
      expect(find.text('Falta: clase'), findsOneWidget);
      expect(find.text('Explorador'), findsNothing);
    });
  });

  group('changing the row type', () {
    testWidgets('drops the other type\'s id and keeps the date',
        (tester) async {
      final saved = _Saved();
      await _open(
        tester,
        _honorRow(
          honorId: 10,
          honor: _firstAidRef,
          completedAt: DateTime(2023, 3, 12),
        ),
        saved,
      );
      await tester.tap(find.text('¿Es una clase?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conquistadores'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explorador').last);
      await tester.pumpAndSettle();
      await _save(tester);

      expect(saved.item!.type, CertificateImportItemType.clazz);
      expect(saved.item!.classId, 3);
      expect(saved.item!.honorId, isNull);
      expect(saved.item!.honor, isNull);
      expect(saved.item!.completedAt, DateTime(2023, 3, 12));
    });

    testWidgets('a new row picks the type with chips and has no quote',
        (tester) async {
      await _open(
        tester,
        CertificateImportItem(
          id: 'new',
          type: CertificateImportItemType.honor,
          status: CertificateImportItemStatus.needsReview,
        ),
        _Saved(),
        isNew: true,
      );
      expect(find.text('Agregar especialidad o clase'), findsOneWidget);
      expect(find.byType(DetectedTextQuote), findsNothing);
      expect(
        find.text('Nombre como aparece en tu comprobante (opcional)'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(GestureDetector, 'Clase').first);
      await tester.pumpAndSettle();
      expect(find.text('Tipo de club'), findsOneWidget);
    });
  });

  group('errors and leaving', () {
    Future<_Saved> failing(WidgetTester tester, Object error,
        {CertificateImportItem? row}) async {
      final saved = _Saved()..failWith = error;
      await _open(
        tester,
        row ??
            _honorRow(
              honorId: 10,
              honor: _firstAidRef,
              completedAt: DateTime(2023, 3, 12),
            ),
        saved,
      );
      await _save(tester);
      return saved;
    }

    testWidgets('a backend date error lands on the date field', (tester) async {
      await failing(
        tester,
        const ServerFailure(
          message: 'x',
          errorCode: 'CERTIFICATE_IMPORT_DATE_TOO_OLD',
        ),
      );
      expect(
          find.text('La fecha no puede ser anterior a 1960'), findsOneWidget);
      expect(find.byType(CertificateImportItemEditorSheet), findsOneWidget);
    });

    testWidgets('a future-date error from the API is shown on the field',
        (tester) async {
      await failing(
        tester,
        const ServerFailure(
          message: 'x',
          errorCode: 'CERTIFICATE_IMPORT_DATE_IN_FUTURE',
        ),
      );
      expect(find.text('La fecha no puede ser futura'), findsOneWidget);
    });

    testWidgets('a club type mismatch lands on the class list', (tester) async {
      await failing(
        tester,
        const ServerFailure(
          message: 'x',
          errorCode: 'CERTIFICATE_IMPORT_CLASS_CLUB_TYPE_MISMATCH',
        ),
        row: _classRow(
          classId: 3,
          classRef: const CertificateImportClassRef(
            id: 3,
            name: 'Explorador',
            clubTypeId: 1,
          ),
          completedAt: DateTime(2022, 11, 20),
        ),
      );
      expect(
        find.text(
            'Esa clase no corresponde al tipo de club. Elígela de nuevo.'),
        findsOneWidget,
      );
    });

    for (final reduced in [false, true]) {
      testWidgets(
          'a network error keeps the sheet and can retry'
          '${reduced ? ' (reduced motion)' : ''}', (tester) async {
        if (reduced) reduceMotion(tester);
        final saved = await failing(
          tester,
          const ServerFailure(message: 'raw', errorCode: 'TIMEOUT'),
        );
        expect(find.text('Revisa tu conexión e inténtalo de nuevo.'),
            findsOneWidget);
        expect(find.textContaining('raw'), findsNothing);
        final save =
            tester.widget<SacButton>(find.widgetWithText(SacButton, 'Guardar'));
        expect(save.isLoading, isFalse);
        expect(save.onPressed, isNotNull);

        saved.failWith = null;
        await _save(tester);
        expect(saved.calls, 2);
        expect(find.byType(CertificateImportItemEditorSheet), findsNothing);
      });
    }

    testWidgets('closing with changes asks first', (tester) async {
      await _open(tester, _honorRow(), _Saved());
      await tester.tap(find.text('Corregir texto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Primeros Auxilios');
      await tester.pump();

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);

      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(find.byType(CertificateImportItemEditorSheet), findsOneWidget);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(CertificateImportItemEditorSheet), findsNothing);
    });

    testWidgets('closing without changes does not ask', (tester) async {
      await _open(tester, _honorRow(), _Saved());
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsNothing);
      expect(find.byType(CertificateImportItemEditorSheet), findsNothing);
    });

    testWidgets('offers to remove an existing row', (tester) async {
      var removed = 0;
      await _open(tester, _honorRow(), _Saved(), onRemove: () => removed++);
      await tester.tap(find.text('Quitar de la lista'));
      expect(removed, 1);
    });
  });

  group('instructor (optional)', () {
    CertificateImportItem completeRow({CertificateImportInstructorRef? by}) =>
        CertificateImportItem(
          id: 'row-1',
          batchId: 'batch-1',
          type: CertificateImportItemType.honor,
          honorId: 10,
          honor: _firstAidRef,
          detectedName: 'Primeros Auxilios',
          completedAt: DateTime(2023, 3, 12),
          status: CertificateImportItemStatus.ready,
          instructor: by,
        );

    const byAna = CertificateImportInstructorRef(
      isUser: true,
      userId: '11111111-1111-4111-8111-111111111111',
      displayName: 'Ana Gómez',
      photoUrl: 'https://r2.example/signed-photo.jpg',
    );

    Future<void> search(WidgetTester tester, String text) async {
      await tester.enterText(
        find.descendant(
          of: find.byType(InstructorPicker),
          matching: find.byType(TextField),
        ),
        text,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }

    testWidgets('is offered on a honor, with the help text, and not on a class',
        (tester) async {
      await _open(tester, completeRow(), _Saved());
      expect(find.text('Instructor o instructora'), findsOneWidget);
      expect(find.text('Agregar instructor (opcional)'), findsOneWidget);
      expect(
        find.text('Tu Campo Local revisa este dato. No avisamos a la persona.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await _open(
        tester,
        _classRow(
          classId: 3,
          classRef: const CertificateImportClassRef(
              id: 3, name: 'Explorador', clubTypeId: 1),
          completedAt: DateTime(2022, 11, 20),
        ),
        _Saved(),
      );
      expect(find.text('Instructor o instructora'), findsNothing);
    });

    testWidgets('does not count for "Falta" and the row is ready without it',
        (tester) async {
      final saved = _Saved();
      await _open(tester, completeRow(), saved);

      expect(find.textContaining('Falta:'), findsNothing);
      await _save(tester);

      expect(saved.item!.status, CertificateImportItemStatus.ready);
      expect(saved.item!.instructor, isNull);
    });

    testWidgets('a person of the Local Field is saved with the user id',
        (tester) async {
      final saved = _Saved();
      await _open(tester, completeRow(), saved);

      await tester.tap(find.text('Agregar instructor (opcional)'));
      await tester.pumpAndSettle();
      await search(tester, 'Ana');
      await tester.tap(find.text('Ana Gómez'));
      await tester.pumpAndSettle();
      await _save(tester);

      final instructor = saved.item!.instructor!;
      expect(instructor.isUser, isTrue);
      expect(instructor.userId, '11111111-1111-4111-8111-111111111111');
      expect(instructor.displayName, 'Ana Gómez');
    });

    testWidgets('a typed name is saved as an external instructor',
        (tester) async {
      final saved = _Saved();
      await _open(tester, completeRow(), saved);

      await tester.tap(find.text('Agregar instructor (opcional)'));
      await tester.pumpAndSettle();
      await search(tester, 'Juan López');
      await tester.tap(find.text('Usar «Juan López» como nombre'));
      await tester.pumpAndSettle();
      expect(find.text('Nombre escrito · no verificado'), findsOneWidget);
      await _save(tester);

      final instructor = saved.item!.instructor!;
      expect(instructor.isUser, isFalse);
      expect(instructor.userId, isNull);
      expect(instructor.displayName, 'Juan López');
    });

    testWidgets('an instructor already on the row is shown and kept as is',
        (tester) async {
      final saved = _Saved();
      await _open(tester, completeRow(by: byAna), saved);

      expect(find.text('Ana Gómez'), findsOneWidget);
      expect(find.text('Persona de tu Campo Local'), findsOneWidget);
      await _save(tester);

      // Same reference: the caller can tell nothing changed.
      expect(saved.item!.instructor, same(byAna));
    });

    testWidgets('removing it saves the row without an instructor',
        (tester) async {
      final saved = _Saved();
      await _open(tester, completeRow(by: byAna), saved);

      await tester.tap(find.widgetWithText(SacButton, 'Quitar'));
      await tester.pumpAndSettle();
      expect(find.text('Agregar instructor (opcional)'), findsOneWidget);
      await _save(tester);

      expect(saved.item!.instructor, isNull);
    });

    testWidgets('switching the row to a class clears the instructor',
        (tester) async {
      final saved = _Saved();
      await _open(tester, completeRow(by: byAna), saved);

      await tester.tap(find.text('¿Es una clase?'));
      await tester.pumpAndSettle();
      expect(find.text('Instructor o instructora'), findsNothing);
      await tester.tap(find.text('Conquistadores'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explorador').last);
      await tester.pumpAndSettle();
      await _save(tester);

      expect(saved.item!.type, CertificateImportItemType.clazz);
      expect(saved.item!.instructor, isNull);
    });

    for (final (code, message) in [
      (
        'HONOR_INSTRUCTOR_INVALID',
        'Esta persona no está disponible. Elige a otra o escribe su nombre',
      ),
      ('HONOR_INSTRUCTOR_SELF', 'No puedes ser tu propio instructor'),
    ]) {
      testWidgets('$code lands on the instructor field, not the banner',
          (tester) async {
        final saved = _Saved()
          ..failWith = ServerFailure(message: 'x', errorCode: code);
        await _open(tester, completeRow(by: byAna), saved);

        await _save(tester);

        expect(find.text(message), findsOneWidget);
        expect(find.byType(CertificateImportItemEditorSheet), findsOneWidget);
        expect(find.textContaining(code), findsNothing);

        // Choosing someone else clears the error.
        await tester.tap(find.widgetWithText(SacButton, 'Quitar'));
        await tester.pumpAndSettle();
        expect(find.text(message), findsNothing);
      });
    }
  });

  testWidgets('SacPickerField shows empty, filled, error and loading',
      (tester) async {
    Widget field({
      String? name,
      String? error,
      bool loading = false,
      String? badge,
    }) =>
        wrapTestApp(Scaffold(
          body: SacPickerField(
            label: 'Campo',
            hint: 'Elige',
            icon: HugeIcons.strokeRoundedMedal05,
            selectedName: name,
            errorText: error,
            isLoading: loading,
            badge: badge,
            onTap: () {},
          ),
        ));

    await tester.pumpWidget(field());
    await tester.pumpAndSettle();
    expect(find.text('Elige'), findsOneWidget);

    await tester.pumpWidget(field(name: 'Valor', badge: 'Sugerida'));
    await tester.pumpAndSettle();
    expect(find.text('Valor'), findsOneWidget);
    expect(find.text('Sugerida'), findsOneWidget);
    expect(find.text('Elige'), findsNothing);

    await tester.pumpWidget(field(error: 'Falta'));
    await tester.pumpAndSettle();
    expect(find.text('Falta'), findsOneWidget);
  });
}
