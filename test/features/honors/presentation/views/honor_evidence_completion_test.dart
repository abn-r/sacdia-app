import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/instructor_picker.dart';
import 'package:sacdia_app/core/widgets/instructor_selection.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/repositories/honors_repository.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_evidence_view.dart';

import '../../../certificate_import/support/test_app.dart';
import '../../../../support/instructor_fakes.dart';

const _anaId = '11111111-1111-4111-8111-111111111111';

/// Plays the API: applies each PATCH to the row, so the refreshed list shows
/// what was saved.
class _FakeHonorsRepository extends Fake implements HonorsRepository {
  _FakeHonorsRepository({
    this.status = 'IN_PROGRESS',
    this.completedAt,
    this.validatedAt,
    this.instructor,
  });

  String status;
  DateTime? completedAt;
  DateTime? validatedAt;
  InstructorSelection? instructor;
  Failure? failWith;
  final patches = <Map<String, dynamic>>[];

  UserHonor get row => UserHonor(
        id: 77,
        honorId: 7,
        userId: 'user-1',
        completionMode: HonorCompletionMode.external,
        validationStatus: status,
        document: 'https://example.com/completed.pdf',
        images: const ['https://example.com/photo.jpg'],
        date: DateTime(2026, 6, 11),
        completedAt: completedAt,
        validatedAt: validatedAt,
        instructor: instructor,
      );

  @override
  Future<Either<Failure, UserHonor>> updateUserHonor(
    String userId,
    int honorId,
    Map<String, dynamic> data,
  ) async {
    patches.add(data);
    final failure = failWith;
    if (failure != null) return Left(failure);
    if (data.containsKey('completedAt')) {
      completedAt = DateTime.parse(data['completedAt'] as String);
    }
    if (data['instructorUserId'] != null) {
      instructor = const InstructorSelection.user(
        id: _anaId,
        displayName: 'Ana Gómez',
      );
    } else if (data['instructorName'] != null) {
      instructor = InstructorSelection.external(data['instructorName']);
    } else if (data.containsKey('instructorUserId')) {
      instructor = null;
    }
    return Right(row);
  }
}

/// The screen keeps a looping animation alive, so `pumpAndSettle` never ends:
/// pump a fixed 1.2 s instead (enough for sheets, dialogs and fades).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeHonorsRepository repo, {
  FakeInstructorSearch? search,
}) async {
  phoneSurface(tester, height: 3200);
  const honor = Honor(
    id: 7,
    name: 'Arte de acampar',
    categoryId: 1,
    approval: 1,
    clubTypeId: 1,
  );
  await tester.pumpWidget(wrapTestApp(
    const HonorEvidenceView(honorId: 7, userHonorId: 77),
    overrides: [
      allHonorsProvider.overrideWith((ref) async => [honor]),
      activeHonorCatalogClubTypeIdProvider
          .overrideWith((ref) => const AsyncValue.data(null)),
      userHonorsProvider.overrideWith((ref) async => [repo.row]),
      honorsRepositoryProvider.overrideWithValue(repo),
      (search ?? FakeInstructorSearch()).override,
    ],
  ));
  await _settle(tester);
}

SacButton _send(WidgetTester tester) =>
    tester.widget(find.widgetWithText(SacButton, 'Enviar a revisión'));

Future<void> _searchAndPick(
    WidgetTester tester, String typed, String label) async {
  await tester.tap(find.text('Agregar instructor (opcional)'));
  await _settle(tester);
  await tester.enterText(
    find.descendant(
      of: find.byType(InstructorPicker),
      matching: find.byType(TextField),
    ),
    typed,
  );
  await tester.pump(const Duration(milliseconds: 300));
  await _settle(tester);
  await tester.tap(find.text(label));
  await _settle(tester);
}

/// How the date field writes a day in Spanish.
String _shown(DateTime d) => DateFormat('d MMM yyyy', 'es').format(d);

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestLocalization);

  group('completion date (mandatory in the app)', () {
    testWidgets('without it the submit is disabled and says why',
        (tester) async {
      await _pump(tester, _FakeHonorsRepository());

      expect(find.text('Fecha de finalización'), findsOneWidget);
      expect(find.text('Obligatoria para enviar a revisión'), findsOneWidget);
      expect(find.text('Elige la fecha de finalización para enviar a revisión'),
          findsOneWidget);
      final button = _send(tester);
      expect(button.isEnabled, isFalse);
      expect(button.onPressed, isNull);
    });

    testWidgets('with it the submit is enabled and the message is gone',
        (tester) async {
      await _pump(
        tester,
        _FakeHonorsRepository(completedAt: DateTime(2026, 9, 30)),
      );

      expect(find.text('Elige la fecha de finalización para enviar a revisión'),
          findsNothing);
      expect(_send(tester).isEnabled, isTrue);
      expect(_send(tester).onPressed, isNotNull);
      expect(find.text(_shown(DateTime(2026, 9, 30))), findsOneWidget);
    });

    testWidgets('picking a day saves completedAt and unlocks the submit',
        (tester) async {
      final repo = _FakeHonorsRepository();
      await _pump(tester, repo);

      await tester.tap(find.text('Seleccionar fecha'));
      await _settle(tester);
      await tester.tap(find.text('ACEPTAR'));
      await _settle(tester);

      expect(repo.patches, [
        {'completedAt': _isoDay(DateTime.now())},
      ]);
      expect(_send(tester).isEnabled, isTrue);
      expect(find.text('Obligatoria para enviar a revisión'), findsNothing);
    });

    testWidgets('the picker runs from 1960-01-01 to today', (tester) async {
      await _pump(tester, _FakeHonorsRepository());

      await tester.tap(find.text('Seleccionar fecha'));
      await _settle(tester);

      final calendar =
          tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
      final now = DateTime.now();
      expect(calendar.firstDate, DateTime(1960, 1, 1));
      expect(calendar.lastDate, DateTime(now.year, now.month, now.day));
    });

    testWidgets('an API range error lands on the field and saves nothing',
        (tester) async {
      final repo = _FakeHonorsRepository()
        ..failWith = const ServerFailure(
          message: 'x',
          code: 400,
          errorCode: 'HONOR_DATE_TOO_OLD',
        );
      await _pump(tester, repo);

      await tester.tap(find.text('Seleccionar fecha'));
      await _settle(tester);
      await tester.tap(find.text('ACEPTAR'));
      await _settle(tester);

      expect(
          find.text('La fecha no puede ser anterior a 1960'), findsOneWidget);
      expect(find.text('Seleccionar fecha'), findsOneWidget);
      expect(_send(tester).isEnabled, isFalse);
    });

    testWidgets('a network failure shows a snack bar and keeps it empty',
        (tester) async {
      final repo = _FakeHonorsRepository()
        ..failWith = const ServerFailure(message: 'x');
      await _pump(tester, repo);

      await tester.tap(find.text('Seleccionar fecha'));
      await _settle(tester);
      await tester.tap(find.text('ACEPTAR'));
      await _settle(tester);

      expect(find.text('No pudimos guardar la fecha. Inténtalo de nuevo'),
          findsOneWidget);
      expect(find.text('Seleccionar fecha'), findsOneWidget);
    });

    testWidgets('a status change elsewhere is explained on the field',
        (tester) async {
      final repo = _FakeHonorsRepository()
        ..failWith = const ServerFailure(
          message: 'x',
          errorCode: 'VALIDATION_HONOR_INVALID_STATUS',
        );
      await _pump(tester, repo);

      await tester.tap(find.text('Seleccionar fecha'));
      await _settle(tester);
      await tester.tap(find.text('ACEPTAR'));
      await _settle(tester);

      expect(
          find.text(
              'Esta especialidad cambió de estado. Actualizamos la pantalla.'),
          findsOneWidget);
    });
  });

  group('instructor (optional)', () {
    testWidgets('does not gate the submit and says nobody is told',
        (tester) async {
      await _pump(
        tester,
        _FakeHonorsRepository(completedAt: DateTime(2026, 9, 30)),
      );

      expect(find.text('Instructor o instructora'), findsOneWidget);
      expect(find.text('Agregar instructor (opcional)'), findsOneWidget);
      expect(
        find.text('Tu Campo Local revisa este dato. No avisamos a la persona.'),
        findsOneWidget,
      );
      expect(_send(tester).isEnabled, isTrue);
    });

    testWidgets('choosing a person saves instructorUserId right away',
        (tester) async {
      final repo = _FakeHonorsRepository();
      await _pump(tester, repo);

      await _searchAndPick(tester, 'Ana', 'Ana Gómez');

      expect(repo.patches, [
        {'instructorUserId': anaGomez.userId},
      ]);
      expect(find.text('Ana Gómez'), findsOneWidget);
      expect(find.text('Persona de tu Campo Local'), findsOneWidget);
    });

    testWidgets('a typed name saves instructorName', (tester) async {
      final repo = _FakeHonorsRepository();
      await _pump(tester, repo);

      await _searchAndPick(
          tester, 'Juan López', 'Usar «Juan López» como nombre');

      expect(repo.patches, [
        {'instructorName': 'Juan López'},
      ]);
      expect(find.text('Nombre escrito · no verificado'), findsOneWidget);
    });

    testWidgets('removing it sends null for both', (tester) async {
      final repo = _FakeHonorsRepository(
        instructor: const InstructorSelection.external('Juan López'),
      );
      await _pump(tester, repo);

      await tester.tap(find.widgetWithText(SacButton, 'Quitar'));
      await _settle(tester);

      expect(repo.patches, [
        {'instructorUserId': null, 'instructorName': null},
      ]);
      expect(find.text('Agregar instructor (opcional)'), findsOneWidget);
    });

    for (final (code, message) in [
      (
        'HONOR_INSTRUCTOR_INVALID',
        'Esta persona no está disponible. Elige a otra o escribe su nombre',
      ),
      ('HONOR_INSTRUCTOR_SELF', 'No puedes ser tu propio instructor'),
    ]) {
      testWidgets('$code is shown on the field and the choice is not kept',
          (tester) async {
        final repo = _FakeHonorsRepository()
          ..failWith = ServerFailure(message: 'x', code: 400, errorCode: code);
        await _pump(tester, repo);

        await _searchAndPick(tester, 'Ana', 'Ana Gómez');

        expect(find.text(message), findsOneWidget);
        expect(find.text('Agregar instructor (opcional)'), findsOneWidget);
        expect(find.textContaining(code), findsNothing);
      });
    }

    testWidgets('any other failure shows a snack bar and goes back',
        (tester) async {
      final repo = _FakeHonorsRepository()
        ..failWith = const ServerFailure(message: 'x');
      await _pump(tester, repo);

      await _searchAndPick(tester, 'Ana', 'Ana Gómez');

      expect(find.text('No pudimos guardar el instructor. Inténtalo de nuevo'),
          findsOneWidget);
      expect(find.text('Agregar instructor (opcional)'), findsOneWidget);
    });

    testWidgets('a rejected honor can be edited again', (tester) async {
      final repo = _FakeHonorsRepository(status: 'REJECTED');
      await _pump(tester, repo);

      await _searchAndPick(tester, 'Ana', 'Ana Gómez');

      expect(repo.patches, hasLength(1));
    });
  });

  group('read-only once it is not in progress or rejected', () {
    testWidgets('under review: shows the declared instructor, nothing editable',
        (tester) async {
      final repo = _FakeHonorsRepository(
        status: 'PENDING_REVIEW',
        completedAt: DateTime(2026, 9, 30),
        instructor: const InstructorSelection.external('Juan López'),
      );
      await _pump(tester, repo);

      expect(find.text('Juan López'), findsOneWidget);
      expect(find.widgetWithText(SacButton, 'Quitar'), findsNothing);
      expect(
          find.text(
              'Tu Campo Local revisa este dato. No avisamos a la persona.'),
          findsNothing);
      expect(find.text('Obligatoria para enviar a revisión'), findsNothing);

      await tester.tap(find.text('Juan López'));
      await _settle(tester);
      await tester.tap(find.text(_shown(DateTime(2026, 9, 30))));
      await _settle(tester);
      expect(find.byType(InstructorPicker), findsNothing);
      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(repo.patches, isEmpty);
    });

    testWidgets('approved without instructor: says so; the date falls back',
        (tester) async {
      final repo = _FakeHonorsRepository(
        status: 'APPROVED',
        validatedAt: DateTime(2026, 10, 2),
      );
      await _pump(tester, repo);

      expect(find.text('Sin instructor registrado'), findsOneWidget);
      expect(find.text('Agregar instructor (opcional)'), findsNothing);
      // No completed_at: shows when it was validated, not the start date.
      expect(find.text(_shown(DateTime(2026, 10, 2))), findsOneWidget);
      expect(find.widgetWithText(SacButton, 'Enviar a revisión'), findsNothing);
    });
  });
}
