import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/activities/presentation/widgets/activity_form_widgets.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/investiture_request.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/presentation_context.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/providers/investiture_requests_providers.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/views/section_investiture_view.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/shared/models/catalogs/ecclesiastical_year_model.dart';

import '../fake_investiture_requests_repository.dart';
import 'investiture_test_harness.dart';

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);

WindowState _openWindow() => WindowState(
      startDate: _today.subtract(const Duration(days: 5)),
      endDate: _today.add(const Duration(days: 30)),
      openToday: true,
    );

PresentationCandidate _candidate(
  int enrollmentId,
  String name, {
  bool eligible = true,
  String? blockedCode,
  String? pendingPersonId,
  num progress = 92,
  String className = 'Amigo',
}) =>
    PresentationCandidate(
      enrollmentId: enrollmentId,
      userId: 'u$enrollmentId',
      userName: name,
      classId: 3,
      className: className,
      overallProgress: progress,
      eligible: eligible,
      blockedCode: blockedCode,
      pendingPersonId: pendingPersonId,
    );

PresentationContext _context({
  WindowState? window,
  bool yearOpen = true,
  String? openRequestId,
  List<PresentationCandidate>? candidates,
}) =>
    PresentationContext(
      clubSectionId: 4,
      ecclesiasticalYearId: 9,
      window: window ?? _openWindow(),
      yearOpen: yearOpen,
      openRequestId: openRequestId,
      candidates: candidates ??
          [
            _candidate(11, 'Ana Pérez'),
            _candidate(12, 'Beto Gómez', progress: 100),
          ],
    );

InvestitureRequest _openRequest({DateTime? date}) => InvestitureRequest(
      requestId: 'r1',
      clubSectionId: 4,
      ecclesiasticalYearId: 9,
      people: [
        RequestPerson(
          personId: 'p1',
          userId: 'u20',
          userName: 'Carla Ruiz',
          classId: 3,
          className: 'Amigo',
          enrollmentId: 20,
          investitureDate: date ?? _today.add(const Duration(days: 10)),
          status: PersonStatus.pending,
        ),
        RequestPerson(
          personId: 'p2',
          userId: 'u21',
          userName: 'Ya Investido',
          classId: 3,
          enrollmentId: 21,
          investitureDate: _today,
          status: PersonStatus.invested,
        ),
      ],
    );

List<Override> _overrides(
  FakeInvestitureRequestsRepository repo, {
  String role = 'director',
}) =>
    [
      investitureRequestsRepositoryProvider.overrideWithValue(repo),
      clubContextProvider.overrideWith(
        (ref) async => ClubContext(clubId: 1, sectionId: 4, roleName: role),
      ),
      currentEcclesiasticalYearProvider.overrideWith(
        (ref) async => EcclesiasticalYearModel(
          ecclesiasticalYearId: 9,
          name: '${_now.year}',
          startDate: DateTime(_now.year - 1, 1, 1),
          endDate: DateTime(_now.year + 1, 12, 31),
          active: true,
        ),
      ),
    ];

Future<void> _pickDateInSheet(WidgetTester tester) async {
  await tester.tap(find.byType(ActivityDatePickerField));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  setUpAll(initInvestitureTestEnv);

  group('SectionInvestitureView', () {
    testWidgets('shows restricted access when the role is not on the board',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()..context = _context();
      await pumpApp(
        tester,
        const SectionInvestitureView(),
        overrides: _overrides(repo, role: 'deputy-director'),
      );

      expect(find.text('Acceso restringido'), findsOneWidget);
      expect(find.textContaining('Presentar ('), findsNothing);
      expect(repo.contextCalls, 0);
    });

    testWidgets('closed window hides present and add actions', (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(
          window: WindowState(
            startDate: _today.subtract(const Duration(days: 60)),
            endDate: _today.subtract(const Duration(days: 10)),
            openToday: false,
          ),
        );
      await pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo));

      expect(
        find.text(
          'La ventana del Campo está cerrada. No se puede presentar ni agregar personas.',
        ),
        findsOneWidget,
      );
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('Presentar ('), findsNothing);
      // Las personas siguen visibles en solo lectura.
      expect(find.text('Ana Pérez'), findsOneWidget);
    });

    testWidgets('invalid time zone is treated as closed with its own message',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(
          window: const WindowState(openToday: false, timeZoneInvalid: true),
        );
      await pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo));

      expect(find.textContaining('zona horaria del Campo no es válida'),
          findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('closed year is read only', (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(yearOpen: false, openRequestId: 'r1')
        ..openRequest = _openRequest();
      await pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo));

      expect(
          find.textContaining('año eclesiástico está cerrado'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Quitar'), findsNothing);
      expect(find.text('Carla Ruiz'), findsOneWidget);
    });

    testWidgets('open window announces the last day', (tester) async {
      final repo = FakeInvestitureRequestsRepository()..context = _context();
      await pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo));

      expect(find.textContaining('Podés presentar hasta el'), findsOneWidget);
    });

    testWidgets('presents two eligible people with the chosen date',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()..context = _context();
      await pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo));

      expect(find.textContaining('Presentar ('), findsNothing);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await settle(tester);
      expect(find.text('Presentar (2)'), findsOneWidget);

      await _tapText(tester, 'Presentar (2)');
      // La hoja pide la fecha y no deja confirmar sin ella.
      expect(find.text('Presentar a investidura'), findsOneWidget);
      final confirm = tester.widget<SacButton>(
        find.widgetWithText(SacButton, 'Presentar'),
      );
      expect(confirm.onPressed, isNull);

      await _pickDateInSheet(tester);
      await settle(tester);
      await tester.tap(find.text('ACEPTAR'));
      await settle(tester);

      await tester.tap(find.widgetWithText(SacButton, 'Presentar'));
      await settle(tester);

      expect(repo.calls, ['present']);
      expect(repo.lastArgs!['enrollmentIds'], [11, 12]);
      final date = repo.lastArgs!['date'] as DateTime;
      expect(DateTime(date.year, date.month, date.day), _today);
      expect(find.text('Solicitud presentada.'), findsOneWidget);
    });

    testWidgets('a blocked candidate shows its reason and has no checkbox',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(candidates: [
          _candidate(
            13,
            'Dani Soto',
            eligible: false,
            blockedCode: 'INVESTITURE_REQUEST_ALREADY_INVESTED',
          ),
          _candidate(
            14,
            'Eli Luna',
            eligible: false,
            blockedCode: 'INVESTITURE_REQUEST_LEGACY_PIPELINE_ACTIVE',
          ),
        ]);
      await pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo));

      expect(find.text('No pueden presentarse'), findsOneWidget);
      expect(find.text('Esa persona ya está investida en esta clase'),
          findsOneWidget);
      expect(
        find.text(
            'Este enrollment sigue en la validación anterior de investidura'),
        findsOneWidget,
      );
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Nadie cumple todavía los requisitos para presentarse.'),
          findsOneWidget);
    });

    testWidgets('with an open request the action adds to it', (tester) async {
      final previous = _today.add(const Duration(days: 10));
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(openRequestId: 'r1')
        ..openRequest = _openRequest(date: previous);
      await pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo));

      // Checkbox 0 = Carla (pendiente); 1 y 2 = candidatas.
      await tester.tap(find.byType(Checkbox).at(1));
      await settle(tester);
      expect(find.text('Agregar a la solicitud (1)'), findsOneWidget);
      expect(find.text('Presentar (1)'), findsNothing);

      await _tapText(tester, 'Agregar a la solicitud (1)');
      // La fecha anterior llega como valor inicial: ya se puede confirmar.
      expect(
          find.textContaining('Fecha actual de la solicitud'), findsOneWidget);
      await tester.tap(find.widgetWithText(SacButton, 'Agregar'));
      await settle(tester);

      expect(repo.calls, ['addPeople']);
      expect(repo.lastArgs!['requestId'], 'r1');
      expect(repo.lastArgs!['enrollmentIds'], [11]);
      final date = repo.lastArgs!['date'] as DateTime;
      expect(DateTime(date.year, date.month, date.day), previous);
    });

    testWidgets('remove asks for confirmation before calling the repository',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(openRequestId: 'r1')
        ..openRequest = _openRequest();
      await pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo));

      await _tapText(tester, 'Quitar');
      expect(find.text('Quitar de la solicitud'), findsOneWidget);
      expect(find.textContaining('No se envía ningún correo'), findsOneWidget);
      expect(repo.calls, isEmpty);

      await _tapText(tester, 'Cancelar');
      expect(repo.calls, isEmpty);

      await _tapText(tester, 'Quitar');
      // El botón de confirmar es el último "Quitar" (el del diálogo).
      await tester.tap(find.text('Quitar').last);
      await settle(tester);

      expect(repo.calls, ['removePerson']);
      expect(repo.lastArgs!['personId'], 'p1');
      expect(find.text('Persona quitada de la solicitud.'), findsOneWidget);
    });

    testWidgets('changes the date of the selected pending people',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(openRequestId: 'r1')
        ..openRequest = _openRequest();
      await pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo));

      await tester.tap(find.byType(Checkbox).first);
      await settle(tester);
      await _tapText(tester, 'Cambiar fecha (1)');
      expect(find.text('Guardar fecha'), findsOneWidget);
      await tester.tap(find.widgetWithText(SacButton, 'Guardar fecha'));
      await settle(tester);

      expect(repo.calls, ['changeDates']);
      expect(repo.lastArgs!['personIds'], ['p1']);
      expect(find.text('Fecha de investidura actualizada.'), findsOneWidget);
    });

    testWidgets('a failed write shows the message and refreshes the data',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(openRequestId: 'r1')
        ..openRequest = _openRequest()
        ..writeFailure =
            const ServerFailure(message: 'Solicitud desactualizada');
      await pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo));
      final before = repo.contextCalls;

      await _tapText(tester, 'Quitar');
      await tester.tap(find.text('Quitar').last);
      await settle(tester);

      expect(find.text('Solicitud desactualizada'), findsOneWidget);
      expect(repo.contextCalls, greaterThan(before));
    });

    testWidgets('shows a retry state when the context fails to load',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..readFailure = const ServerFailure(message: 'sin conexión');
      await pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo));

      expect(find.text('No pudimos cargar las investiduras'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      repo.readFailure = null;
      repo.context = _context();
      await _tapText(tester, 'Reintentar');
      expect(find.text('Ana Pérez'), findsOneWidget);
    });

    testWidgets('pull to refresh reloads context and open request',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()..context = _context();
      await pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo));
      final contextBefore = repo.contextCalls;
      final openBefore = repo.openRequestCalls;

      await tester.fling(
          find.byType(ListView).first, const Offset(0, 400), 1000);
      await settle(tester);

      expect(repo.contextCalls, greaterThan(contextBefore));
      expect(repo.openRequestCalls, greaterThan(openBefore));
    });

    testWidgets('shows the empty state when nobody is in the section',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(candidates: const []);
      await pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo));

      expect(
          find.text('Todavía no hay personas para presentar'), findsOneWidget);
    });
  });
}
