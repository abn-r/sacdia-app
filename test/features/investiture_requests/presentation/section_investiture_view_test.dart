import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/widgets/investiture_rows.dart';
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
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import '../../../support/capability_fixtures.dart';

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
  int? missing,
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
      missingRequirementsCount: missing,
    );

const _samuel = InvestitureActor(userId: 'pa', name: 'Samuel Ibarra');

PresentationContext _context({
  WindowState? window,
  bool yearOpen = true,
  String? openRequestId,
  List<PresentationCandidate>? candidates,
  List<InvestitureActor> authorizers = const [_samuel],
}) =>
    PresentationContext(
      clubSectionId: 4,
      ecclesiasticalYearId: 9,
      window: window ?? _openWindow(),
      yearOpen: yearOpen,
      openRequestId: openRequestId,
      authorizers: authorizers,
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
      createdAt: DateTime(2026, 11, 8),
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
      authNotifierProvider.overrideWith(() => _FakeAuth(_sessionUserFor(role))),
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

/// Sesión con la concesión activa de [role] y las capacidades que el servidor
/// publicaría para ella (`investiture.board` para la directiva).
UserEntity _sessionUserFor(String role) => UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      postRegisterComplete: true,
      authorization: AuthorizationSnapshot(
        activeAssignmentId: 'a1',
        clubAssignments: [
          AuthorizationGrant(
            assignmentId: 'a1',
            roleName: role,
            clubId: 1,
            sectionId: 4,
            status: 'active',
          ),
        ],
        capabilities: capabilitiesFor(activeClubRole: role),
      ),
    );

class _FakeAuth extends AuthNotifier {
  _FakeAuth(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

void main() {
  setUpAll(initInvestitureTestEnv);

  Future<void> pumpBoard(
    WidgetTester tester,
    FakeInvestitureRequestsRepository repo, {
    String role = 'director',
  }) =>
      pumpApp(tester, const SectionInvestitureView(),
          overrides: _overrides(repo, role: role));

  bool footerEnabled(WidgetTester tester, String text) =>
      tester.widget<SacButton>(find.widgetWithText(SacButton, text)).isEnabled;

  group('SectionInvestitureView', () {
    testWidgets('restricted access says who can and links to Mi investidura',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()..context = _context();
      await pumpBoard(tester, repo, role: 'deputy-director');

      expect(find.text('Solo la directiva del club'), findsOneWidget);
      expect(find.text('Mi investidura'), findsOneWidget);
      expect(find.textContaining('Enviar a autorización'), findsNothing);
      expect(repo.contextCalls, 0);
    });

    testWidgets('closed window: says when it closed and disables sending',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(
          window: WindowState(
            startDate: _today.subtract(const Duration(days: 60)),
            endDate: _today.subtract(const Duration(days: 10)),
            openToday: false,
          ),
        );
      await pumpBoard(tester, repo);

      expect(find.text('Ventana del Campo cerrada'), findsOneWidget);
      expect(find.textContaining('Cerró el'), findsOneWidget);
      expect(find.byType(InvestitureSelectBox), findsNothing);
      expect(find.text('Envío cerrado'), findsOneWidget);
      expect(footerEnabled(tester, 'Envío cerrado'), isFalse);
      // Las personas siguen visibles en solo lectura.
      expect(find.text('Ana Pérez'), findsOneWidget);
    });

    testWidgets('without a configured window nobody can present or move dates',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(
          openRequestId: 'r1',
          window: const WindowState(openToday: true),
        )
        ..openRequest = _openRequest();
      await pumpBoard(tester, repo);

      expect(find.text('Ventana del Campo cerrada'), findsOneWidget);
      expect(find.byType(InvestitureSelectBox), findsNothing);
      expect(footerEnabled(tester, 'Envío cerrado'), isFalse);
      expect(find.text('Carla Ruiz'), findsOneWidget);

      // Con la ventana sin configurar tampoco se puede retirar a nadie.
      await _tapText(tester, 'Carla Ruiz');
      expect(find.text('Retirar de la solicitud'), findsNothing);
    });

    testWidgets('invalid time zone is closed with its own message',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(
          window: const WindowState(openToday: false, timeZoneInvalid: true),
        );
      await pumpBoard(tester, repo);

      expect(find.text('Zona horaria del Campo no válida'), findsOneWidget);
      expect(find.byType(InvestitureSelectBox), findsNothing);
    });

    testWidgets('closed year is read only', (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(yearOpen: false, openRequestId: 'r1')
        ..openRequest = _openRequest();
      await pumpBoard(tester, repo);

      expect(find.text('Año eclesiástico cerrado'), findsOneWidget);
      expect(find.byType(InvestitureSelectBox), findsNothing);
      await _tapText(tester, 'Carla Ruiz');
      // La hoja solo informa: ni cambiar fecha ni retirar.
      expect(find.text('Autoriza'), findsOneWidget);
      expect(find.text('Retirar de la solicitud'), findsNothing);
    });

    testWidgets('open window shows the last day inside the summary',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()..context = _context();
      await pumpBoard(tester, repo);

      expect(find.textContaining('Ventana del Campo abierta hasta el'),
          findsOneWidget);
      expect(find.text('Listos para investidura'), findsOneWidget);
      expect(find.text('2 de 2'), findsOneWidget);
    });

    testWidgets('summary counts waiting, ready and not yet', (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(
          openRequestId: 'r1',
          candidates: [
            _candidate(11, 'Ana Pérez'),
            _candidate(13, 'Dani Soto', eligible: false, progress: 40),
          ],
        )
        ..openRequest = _openRequest();
      await pumpBoard(tester, repo);

      final summary = tester.widget<Text>(
        find.byKey(const ValueKey('board-summary-ready')),
      );
      expect(summary.textSpan!.toPlainText(), '1 de 3  ·  1 en espera');
      expect(find.textContaining('En espera 1', findRichText: true),
          findsOneWidget);
      expect(
          find.textContaining('Listos 1', findRichText: true), findsOneWidget);
      expect(
          find.textContaining('Aún no 1', findRichText: true), findsOneWidget);
    });

    testWidgets('ready people come preselected and one button sends them',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()..context = _context();
      await pumpBoard(tester, repo);

      // Nada que elegir: ya vienen elegidos.
      expect(find.text('Enviar a autorización (2)'), findsOneWidget);
      expect(
          find.text('Pastor del distrito: Ptr. Samuel Ibarra'), findsOneWidget);

      await _tapText(tester, 'Enviar a autorización (2)');
      // La hoja dice quién revisa y que el progreso se bloquea.
      expect(find.text('Enviar 2 a autorización'), findsOneWidget);
      expect(find.textContaining('Las revisará Ptr. Samuel Ibarra.'),
          findsOneWidget);
      expect(
          find.textContaining('su progreso queda bloqueado'), findsOneWidget);
      // Fecha obligatoria: sin ella no se puede enviar.
      final confirm = tester.widget<SacButton>(
        find.widgetWithText(SacButton, 'Enviar'),
      );
      expect(confirm.onPressed, isNull);

      await _pickDateInSheet(tester);
      await settle(tester);
      await tester.tap(find.text('Aceptar'));
      await settle(tester);
      await tester.tap(find.widgetWithText(SacButton, 'Enviar'));
      await settle(tester);

      expect(repo.calls, ['present']);
      expect(repo.lastArgs!['enrollmentIds'], [11, 12]);
      final date = repo.lastArgs!['date'] as DateTime;
      expect(DateTime(date.year, date.month, date.day), _today);
      expect(find.text('2 personas enviadas a Ptr. Samuel Ibarra'),
          findsOneWidget);
    });

    testWidgets('a person can be taken off the selection, and all at once',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()..context = _context();
      await pumpBoard(tester, repo);

      expect(find.text('Quitar todos'), findsOneWidget);
      await _tapText(tester, 'Ana Pérez');
      expect(find.text('Enviar a autorización (1)'), findsOneWidget);
      expect(find.text('Elegir todos'), findsOneWidget);

      await _tapText(tester, 'Elegir todos');
      expect(find.text('Enviar a autorización (2)'), findsOneWidget);

      await _tapText(tester, 'Quitar todos');
      expect(find.text('Enviar a autorización (0)'), findsOneWidget);
      expect(footerEnabled(tester, 'Enviar a autorización (0)'), isFalse);
    });

    testWidgets('with an open request it still calls present, never addPeople',
        (tester) async {
      final previous = _today.add(const Duration(days: 10));
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(openRequestId: 'r1')
        ..openRequest = _openRequest(date: previous);
      await pumpBoard(tester, repo);

      await _tapText(tester, 'Enviar a autorización (2)');
      // La fecha de la solicitud llega como valor inicial: ya se puede enviar.
      await tester.tap(find.widgetWithText(SacButton, 'Enviar'));
      await settle(tester);

      expect(repo.calls, ['present']);
      final date = repo.lastArgs!['date'] as DateTime;
      expect(DateTime(date.year, date.month, date.day), previous);
    });

    group('pastor name', () {
      testWidgets('several authorizers: first name and how many more',
          (tester) async {
        final repo = FakeInvestitureRequestsRepository()
          ..context = _context(authorizers: const [
            _samuel,
            InvestitureActor(userId: 'pb', name: 'Raúl Díaz'),
            InvestitureActor(userId: 'pc', name: 'Marta Gil'),
          ]);
        await pumpBoard(tester, repo);

        expect(find.text('Pastor del distrito: Ptr. Samuel Ibarra y 2 más'),
            findsOneWidget);
      });

      testWidgets('no authorizers: generic copy without a name',
          (tester) async {
        final repo = FakeInvestitureRequestsRepository()
          ..context = _context(authorizers: const []);
        await pumpBoard(tester, repo);

        expect(
            find.text('Las revisará el pastor del distrito.'), findsOneWidget);
        expect(find.textContaining('Ptr.'), findsNothing);

        await _tapText(tester, 'Enviar a autorización (2)');
        expect(find.textContaining('Las revisará el pastor del distrito.'),
            findsWidgets);
      });
    });

    testWidgets('a waiting person opens a sheet with who authorizes',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(openRequestId: 'r1')
        ..openRequest = _openRequest();
      await pumpBoard(tester, repo);

      expect(find.text('EN ESPERA DE AUTORIZACIÓN'), findsOneWidget);
      await _tapText(tester, 'Carla Ruiz');

      expect(find.textContaining('enviado el 8 nov'), findsOneWidget);
      expect(find.text('Cambiar fecha'), findsOneWidget);
      expect(find.text('Autoriza'), findsOneWidget);
      expect(find.text('Ptr. Samuel Ibarra'), findsOneWidget);
      expect(find.text('Retirar de la solicitud'), findsOneWidget);
    });

    testWidgets('waiting sheet: withdraw asks for confirmation first',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(openRequestId: 'r1')
        ..openRequest = _openRequest();
      await pumpBoard(tester, repo);

      await _tapText(tester, 'Carla Ruiz');
      await _tapText(tester, 'Retirar de la solicitud');
      expect(find.textContaining('No se envía ningún correo'), findsOneWidget);
      expect(repo.calls, isEmpty);

      await _tapText(tester, 'Cancelar');
      expect(repo.calls, isEmpty);

      await _tapText(tester, 'Carla Ruiz');
      await _tapText(tester, 'Retirar de la solicitud');
      await tester.tap(find.text('Retirar').last);
      await settle(tester);

      expect(repo.calls, ['removePerson']);
      expect(repo.lastArgs!['personId'], 'p1');
      expect(find.text('Persona retirada de la solicitud.'), findsOneWidget);
    });

    testWidgets('waiting sheet: changes the date of that person',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(openRequestId: 'r1')
        ..openRequest = _openRequest();
      await pumpBoard(tester, repo);

      await _tapText(tester, 'Carla Ruiz');
      await _tapText(tester, 'Cambiar fecha');
      expect(find.text('Guardar fecha'), findsOneWidget);
      await tester.tap(find.widgetWithText(SacButton, 'Guardar fecha'));
      await settle(tester);

      expect(repo.calls, ['changeDates']);
      expect(repo.lastArgs!['personIds'], ['p1']);
      expect(find.text('Fecha de investidura actualizada.'), findsOneWidget);
    });

    testWidgets('the menu offers history, yearbook and changing the date',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(openRequestId: 'r1')
        ..openRequest = _openRequest();
      await pumpBoard(tester, repo);

      await tester.tap(find.byTooltip('Más opciones'));
      await settle(tester);
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Anuario'), findsOneWidget);
      await tester.tap(find.text('Cambiar fecha'));
      await settle(tester);

      // Cambia la fecha de todas las personas en espera.
      await tester.tap(find.widgetWithText(SacButton, 'Guardar fecha'));
      await settle(tester);
      expect(repo.calls, ['changeDates']);
      expect(repo.lastArgs!['personIds'], ['p1']);
    });

    testWidgets('the menu hides changing the date with nobody waiting',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()..context = _context();
      await pumpBoard(tester, repo);

      await tester.tap(find.byTooltip('Más opciones'));
      await settle(tester);
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Cambiar fecha'), findsNothing);
    });

    testWidgets('not yet: shows how many requirements are missing and the %',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(candidates: [
          _candidate(11, 'Ana Pérez'),
          _candidate(13, 'Dani Soto',
              eligible: false, progress: 62, missing: 5),
          _candidate(
            14,
            'Eli Luna',
            eligible: false,
            progress: 80,
            blockedCode: 'INVESTITURE_REQUEST_LEGACY_PIPELINE_ACTIVE',
          ),
          _candidate(15, 'Fer Mora', eligible: false, progress: 30, missing: 1),
        ]);
      await pumpBoard(tester, repo);

      expect(find.text('AÚN NO CUMPLEN'), findsOneWidget);
      expect(find.textContaining('Faltan 5 requisitos'), findsOneWidget);
      expect(find.textContaining('Falta 1 requisito'), findsOneWidget);
      expect(find.textContaining('validación anterior de investidura'),
          findsOneWidget);
      expect(find.text('62%'), findsOneWidget);
      // Sin casilla: no se pueden enviar.
      expect(find.byType(InvestitureSelectBox), findsNWidgets(1));
    });

    testWidgets('not yet: a row opens that member\'s progress (grouped class)',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(candidates: [
          _candidate(13, 'Dani Soto',
              eligible: false, progress: 62, missing: 5),
        ]);
      String? opened;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const SectionInvestitureView(),
          ),
          GoRoute(
            path: '/home/grouped-class/class/:classId/member/:userId',
            builder: (_, state) {
              opened = state.uri.toString();
              return const Scaffold(body: Text('member-progress'));
            },
          ),
        ],
      );
      await pumpRouterApp(tester, router, overrides: _overrides(repo));

      await _tapText(tester, 'Dani Soto');

      expect(find.text('member-progress'), findsOneWidget);
      final uri = Uri.parse(opened!);
      expect(uri.path, '/home/grouped-class/class/3/member/u13');
      expect(uri.queryParameters['clubId'], '1');
      expect(uri.queryParameters['sectionId'], '4');
      expect(uri.queryParameters['enrollmentId'], '13');
      expect(uri.queryParameters['memberName'], 'Dani Soto');
    });

    testWidgets('nobody ready: says so and shows who is closest',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(candidates: [
          _candidate(13, 'Dani Soto',
              eligible: false, progress: 40, missing: 6),
          _candidate(14, 'Eli Luna', eligible: false, progress: 90, missing: 1),
        ]);
      await pumpBoard(tester, repo);

      expect(find.text('Aún nadie está listo'), findsOneWidget);
      expect(find.text('MÁS CERCA'), findsOneWidget);
      // La más avanzada primero.
      expect(
        tester.getTopLeft(find.text('Eli Luna')).dy,
        lessThan(tester.getTopLeft(find.text('Dani Soto')).dy),
      );
      expect(find.textContaining('Enviar a autorización'), findsNothing);
    });

    testWidgets('a failed write shows the message and refreshes the data',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..context = _context(openRequestId: 'r1')
        ..openRequest = _openRequest()
        ..writeFailure =
            const ServerFailure(message: 'Solicitud desactualizada');
      await pumpBoard(tester, repo);
      final before = repo.contextCalls;

      await _tapText(tester, 'Carla Ruiz');
      await _tapText(tester, 'Retirar de la solicitud');
      await tester.tap(find.text('Retirar').last);
      await settle(tester);

      expect(find.text('Solicitud desactualizada'), findsOneWidget);
      expect(repo.contextCalls, greaterThan(before));
    });

    testWidgets('shows a retry state when the context fails to load',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..readFailure = const ServerFailure(message: 'Falló el servidor');
      await pumpBoard(tester, repo);

      expect(find.text('No pudimos cargar las investiduras'), findsOneWidget);
      expect(find.text('Falló el servidor'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      repo.readFailure = null;
      repo.context = _context();
      await _tapText(tester, 'Reintentar');
      expect(find.text('Ana Pérez'), findsOneWidget);
    });

    testWidgets('offline says so instead of a generic error', (tester) async {
      final repo = FakeInvestitureRequestsRepository()
        ..readFailure = const ConnectionFailure(message: 'timeout');
      await pumpBoard(tester, repo);

      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.textContaining('necesitan internet'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('pull to refresh reloads context and open request',
        (tester) async {
      final repo = FakeInvestitureRequestsRepository()..context = _context();
      await pumpBoard(tester, repo);
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
      await pumpBoard(tester, repo);

      expect(find.text('Todavía no hay personas para enviar'), findsOneWidget);
    });
  });
}
