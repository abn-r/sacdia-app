import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_event.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_leaderboard.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_member.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_official_score.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_score_breakdown.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_offering.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/providers/camporee_orders_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_detail_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../support/riverpod_test_support.dart';

class _TestAuthNotifier extends AuthNotifier {
  final UserEntity? user;

  _TestAuthNotifier(this.user);

  @override
  Future<UserEntity?> build() async => user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('panel aparece antes de miembros y pending bloquea fail-closed',
      (tester) async {
    var memberLoads = 0;
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.pendingApproval,
      ),
      onMembersLoad: () => memberLoads += 1,
      user: _director,
    );

    expect(find.text('Detalle'), findsWidgets);
    expect(
      find.text('INSCRIPCIÓN DE LA SECCIÓN', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.textContaining('MIEMBROS INSCRITOS'), findsNothing);
    expect(memberLoads, 0);

    await _openTab(tester, 'Asistentes');

    expect(find.textContaining('MIEMBROS INSCRITOS'), findsOneWidget);
    expect(
      find.text(
        'La inscripción de participantes está bloqueada hasta que la sección esté registrada y habilitada.',
      ),
      findsOneWidget,
    );
    expect(find.text('Inscribir participantes'), findsNothing);
    expect(find.widgetWithText(SacButton, 'Inscribir'), findsNothing);
    expect(memberLoads, 0);
  });

  testWidgets('la pestaña activa se distingue con el thumb desplazado',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      user: _director,
      onMembersLoad: () {},
    );

    final thumb = tester.widget<Positioned>(
      find.byKey(const Key('camporee-detail-tab-thumb')),
    );
    expect(thumb.left, 0);

    await _openTab(tester, 'Asistentes');

    final moved = tester.widget<Positioned>(
      find.byKey(const Key('camporee-detail-tab-thumb')),
    );
    expect(moved.left, greaterThan(40));
  });

  testWidgets('registered habilita carga y acción de participantes',
      (tester) async {
    var memberLoads = 0;
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () => memberLoads += 1,
    );

    expect(memberLoads, 1);
    await _openTab(tester, 'Asistentes');
    expect(find.text('Inscribir participantes'), findsOneWidget);
    final enrollButton = tester.widget<SacButton>(
      find.widgetWithText(SacButton, 'Inscribir participantes'),
    );
    expect(enrollButton.onPressed, isNotNull);
  });

  testWidgets('deputy conserva lectura pero no ve altas de participantes',
      (tester) async {
    var memberLoads = 0;
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      user: _deputy,
      onMembersLoad: () => memberLoads += 1,
    );

    expect(memberLoads, 1);
    await _openTab(tester, 'Asistentes');
    expect(find.text('Inscribir participantes'), findsNothing);
    expect(find.widgetWithText(SacButton, 'Inscribir'), findsNothing);
  });

  testWidgets('error de miembros muestra mensaje y reintenta el provider',
      (tester) async {
    var memberLoads = 0;
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () => memberLoads += 1,
      failMembersOnce: true,
    );

    await _openTab(tester, 'Asistentes');

    expect(
        find.text('No pudimos cargar los miembros inscritos.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(memberLoads, 1);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(memberLoads, 2);
  });

  testWidgets('loading de miembros anuncia participantes como live region',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      keepMembersLoading: true,
    );

    await _openTab(tester, 'Asistentes');

    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Cargando participantes inscritos',
      ),
    );
    expect(semantics.properties.liveRegion, isTrue);
  });

  testWidgets('muestra la clasificación oficial y resalta la sección propia',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      leaderboard: const CamporeeLeaderboard(
        scopeType: 'local',
        camporeeId: 41,
        rows: [
          CamporeeLeaderboardRow(
            rank: 1,
            camporeeClubId: 5,
            clubSectionId: 12,
            clubName: 'ACV',
            sectionName: 'Conquistadores',
            totalAwardedPoints: 85,
            totalMaxPoints: 100,
            percentage: 85,
          ),
        ],
      ),
    );

    await _openTab(tester, 'Eventos');
    await tester.scrollUntilVisible(
      find.text('CLASIFICACIÓN'),
      400,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    expect(find.text('CLASIFICACIÓN'), findsOneWidget);
    expect(find.text('ACV'), findsOneWidget);
    expect(find.text('85 / 100'), findsOneWidget);
    // Row 12 is the user's own section (registration.clubSectionId).
    expect(find.text('Tu sección'), findsOneWidget);
  });

  testWidgets(
      'un rol de club solo ve el puntaje de su sección, sin posición ni ranking',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      leaderboard: const CamporeeLeaderboard(
        scopeType: 'local',
        camporeeId: 41,
        isFullRanking: false,
        rows: [
          CamporeeLeaderboardRow(
            camporeeClubId: 5,
            clubSectionId: 12,
            clubName: 'ACV',
            sectionName: 'Conquistadores',
            totalAwardedPoints: 1035,
            totalMaxPoints: 1200,
            percentage: 86.25,
          ),
        ],
      ),
    );

    await _openTab(tester, 'Eventos');
    await tester.scrollUntilVisible(
      find.text('PUNTAJE DE TU SECCIÓN'),
      400,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    expect(find.text('PUNTAJE DE TU SECCIÓN'), findsOneWidget);
    expect(find.text('CLASIFICACIÓN'), findsNothing);
    expect(find.text('ACV'), findsOneWidget);
    expect(find.text('1035 / 1200'), findsOneWidget);
    // No position, no "your section" badge, no "see all" toggle.
    expect(find.text('1'), findsNothing);
    expect(find.text('Tu sección'), findsNothing);
    expect(find.byKey(const Key('camporee-leaderboard-toggle')), findsNothing);
  });

  testWidgets('pins «Inscribir mi sección» only while the section can enroll',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.notEnrolled,
        canEnroll: true,
      ),
      onMembersLoad: () {},
      user: _director,
    );
    expect(find.byKey(const Key('camporee-enroll-bar')), findsOneWidget);

    await _openTab(tester, 'Asistentes');
    expect(find.byKey(const Key('camporee-enroll-bar')), findsNothing);
  });

  testWidgets('pins «Inscribir participantes» on Asistentes for the director',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      user: _director,
    );
    expect(find.byKey(const Key('camporee-participants-bar')), findsNothing);

    await _openTab(tester, 'Asistentes');
    expect(find.byKey(const Key('camporee-participants-bar')), findsOneWidget);
  });

  testWidgets('a registered section shows no enroll bar', (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      user: _director,
    );
    expect(find.byKey(const Key('camporee-enroll-bar')), findsNothing);
    expect(find.text('Asistentes'), findsWidgets);
  });

  testWidgets(
      'should not stack a duplicate Camporí banner above the facts card',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
    );

    expect(find.text('Detalle del Camporí'), findsNothing);
    expect(find.byKey(const Key('camporee-detail-tab-info')), findsOneWidget);
    expect(find.byKey(const Key('camporee-detail-tab-people')), findsOneWidget);
    expect(find.byKey(const Key('camporee-detail-tab-events')), findsOneWidget);
    expect(find.byKey(const Key('camporee-detail-tab-agenda')), findsOneWidget);
    expect(find.text('Fechas'), findsOneWidget);
    // The bar names the screen; the camporee name lives in the header only.
    expect(find.widgetWithText(AppBar, 'Camporee'), findsOneWidget);
    expect(find.text('Camporí Esperanza'), findsOneWidget);
  });

  testWidgets('should hide a description that only repeats the camporee name',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      camporee: Camporee(
        camporeeId: 41,
        name: 'Navegando con Jesús',
        description: 'Camporee Navegando con Jesús',
        startDate: DateTime(2026, 8, 15),
        endDate: DateTime(2026, 8, 18),
        place: 'Valle Verde',
        registrationCost: 125,
        includesAdventurers: true,
        includesPathfinders: true,
        includesMasterGuides: false,
        active: true,
      ),
    );

    expect(find.text('DESCRIPCIÓN', skipOffstage: false), findsNothing);
    expect(
      find.text('Camporee Navegando con Jesús', skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('should keep a description that adds information',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      camporee: Camporee(
        camporeeId: 41,
        name: 'Navegando con Jesús',
        description: 'Llevar linterna y saco de dormir.',
        startDate: DateTime(2026, 8, 15),
        endDate: DateTime(2026, 8, 18),
        place: 'Valle Verde',
        registrationCost: 125,
        includesAdventurers: true,
        includesPathfinders: true,
        includesMasterGuides: false,
        active: true,
      ),
    );

    expect(find.text('DESCRIPCIÓN', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Llevar linterna y saco de dormir.', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('should let enrolled member names wrap to two lines',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      members: const [
        CamporeeMember(
          camporeeMemberId: 1,
          userId: 'director-1',
          userName: 'Director Club Test Aventureros',
          clubName: 'ACV',
          insuranceVerified: true,
          active: true,
        ),
      ],
    );

    await _openTab(tester, 'Asistentes');

    final name = tester.widget<Text>(
      find.text('Director Club Test Aventureros'),
    );
    expect(name.maxLines, 2);
    expect(find.text('Seguro OK'), findsNothing);
  });

  testWidgets('Eventos muestra solo actividades con puntuación',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      events: _programEvents,
    );

    await _openTab(tester, 'Eventos');

    expect(find.text('Orden cerrado'), findsOneWidget);
    expect(find.text('Nudos'), findsOneWidget);
    expect(find.text('Culto de apertura'), findsNothing);
    expect(find.text('Fútbol recreativo'), findsNothing);
    expect(find.text('Tiempo de descanso'), findsNothing);
  });

  testWidgets('el detalle del evento lista sus adjuntos', (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      events: [
        _event(
          id: 11,
          title: 'Orden cerrado',
          day: 1,
          startsAt: '08:00',
          scoring: true,
          typeCode: 'scoring',
          typeName: 'Puntuable',
          category: 'competencia',
          attachments: const [
            CamporeeEventAttachment(
              attachmentId: 'a-1',
              fileName: 'Reglamento de marcha.pdf',
              mimeType: 'application/pdf',
              sizeBytes: 245760,
              url: 'https://r2.example/reglamento.pdf',
            ),
            CamporeeEventAttachment(
              attachmentId: 'a-2',
              fileName: 'Mapa de la explanada.png',
              mimeType: 'image/png',
              sizeBytes: 1572864,
              url: 'https://r2.example/mapa.png',
            ),
          ],
        ),
      ],
    );

    await _openTab(tester, 'Eventos');
    await tester.tap(find.text('Orden cerrado'));
    await tester.pumpAndSettle();

    expect(find.text('ADJUNTOS · 2'), findsOneWidget);
    expect(find.text('Reglamento de marcha.pdf'), findsOneWidget);
    expect(find.text('PDF · 240 KB'), findsOneWidget);
    expect(find.text('Imagen · 1.5 MB'), findsOneWidget);
  });

  testWidgets(
      'own view: events list shows the section points and the detail '
      'shows rubric and judge comments', (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      events: _scoredEvents,
      breakdown: _breakdown(visibility: 'own', sections: [
        _breakdownSection(12, 'ACV', awarded: 430),
      ]),
    );

    await _openTab(tester, 'Eventos');
    expect(find.text('430 / 500'), findsOneWidget);
    // Event without a result keeps the max points.
    expect(find.text('100 pts'), findsOneWidget);

    await tester.tap(find.text('Orden cerrado'));
    await tester.pumpAndSettle();

    expect(find.text('TU PUNTAJE'), findsOneWidget);
    expect(find.text('430 / 500'), findsOneWidget);
    expect(find.text('Uniforme'), findsOneWidget);
    expect(find.text('250 / 300'), findsOneWidget);
    expect(find.text('Falta pañoleta'), findsOneWidget);
    expect(find.text('Comentario del juez'), findsOneWidget);
    expect(find.text('Buena formación'), findsOneWidget);
    expect(find.textContaining('Evaluó Ana Ruiz'), findsOneWidget);
  });

  testWidgets('own view: no result yet shows the empty message',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      events: _scoredEvents,
      breakdown: _breakdown(visibility: 'own', sections: []),
    );

    await _openTab(tester, 'Eventos');
    await tester.tap(find.text('Orden cerrado'));
    await tester.pumpAndSettle();

    expect(
      find.text('Tu sección aún no tiene puntaje en este evento.'),
      findsOneWidget,
    );
  });

  testWidgets('full view: lists every section and opens the detail sheet',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      user: _director,
      events: _scoredEvents,
      breakdown: _breakdown(visibility: 'full', sections: [
        _breakdownSection(12, 'ACV', awarded: 300, rank: 2),
        _breakdownSection(13, 'Orión', awarded: 450, rank: 1),
      ]),
    );

    await _openTab(tester, 'Eventos');
    // The list keeps the max points for non-own visibility.
    expect(find.text('430 / 500'), findsNothing);

    await tester.tap(find.text('Orden cerrado'));
    await tester.pumpAndSettle();

    expect(find.text('PUNTAJES · 2'), findsOneWidget);
    expect(find.text('450 / 500'), findsOneWidget);
    expect(find.text('300 / 500'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Orión')).dy,
      lessThan(tester.getTopLeft(find.text('ACV')).dy),
    );

    await tester.tap(find.text('Orión'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('camporee-event-score-sheet')), findsOneWidget);
    expect(find.text('Falta pañoleta'), findsOneWidget);
    expect(find.text('Buena formación'), findsOneWidget);
  });

  testWidgets('Agenda lista todo el programa en orden cronológico',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      events: _programEvents,
    );

    await _openTab(tester, 'Agenda');

    expect(find.text('Culto de apertura'), findsOneWidget);
    expect(find.text('Orden cerrado'), findsOneWidget);
    expect(find.text('Nudos'), findsOneWidget);
    expect(find.text('Fútbol recreativo'), findsOneWidget);
    expect(find.text('Tiempo de descanso'), findsOneWidget);
    expect(find.textContaining('DÍA 1'), findsOneWidget);
    expect(find.textContaining('DÍA 2'), findsOneWidget);

    final culto = tester.getTopLeft(find.text('Culto de apertura'));
    final orden = tester.getTopLeft(find.text('Orden cerrado'));
    final nudos = tester.getTopLeft(find.text('Nudos'));
    final descanso = tester.getTopLeft(find.text('Tiempo de descanso'));
    final futbol = tester.getTopLeft(find.text('Fútbol recreativo'));
    expect(culto.dy, lessThan(orden.dy));
    expect(orden.dy, lessThan(nudos.dy));
    expect(nudos.dy, lessThan(descanso.dy));
    expect(descanso.dy, lessThan(futbol.dy));
  });

  testWidgets('Agenda oculta hora y sede si el preview aún no libera horarios',
      (tester) async {
    await _pumpDetail(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      onMembersLoad: () {},
      events: [
        _event(
          id: 11,
          title: 'Culto de apertura',
          day: 1,
          startsAt: '07:00',
          venueName: 'Auditorio',
          typeCode: 'spiritual',
          typeName: 'Espiritual',
          category: 'espiritual',
          agendaVisible: false,
        ),
      ],
    );

    await _openTab(tester, 'Agenda');

    expect(find.text('Culto de apertura'), findsOneWidget);
    expect(find.text('07:00'), findsNothing);
    expect(find.text('Auditorio'), findsNothing);
    expect(find.textContaining('DÍA 1'), findsNothing);
    expect(find.text('AGENDA PENDIENTE'), findsOneWidget);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required CamporeeSectionRegistration registration,
  required VoidCallback onMembersLoad,
  UserEntity? user = _director,
  bool failMembersOnce = false,
  bool keepMembersLoading = false,
  CamporeeLeaderboard? leaderboard,
  CamporeeScoreBreakdown? breakdown,
  Camporee? camporee,
  List<CamporeeMember> members = const [],
  List<CamporeeEvent> events = const [],
}) async {
  var failed = false;
  final loading = Completer<List<CamporeeMember>>();
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _TestAuthNotifier(user)),
        camporeeDetailProvider
            .overrideWith((ref, id) async => camporee ?? _camporee),
        camporeeSectionRegistrationProvider
            .overrideWith((ref, id) async => registration),
        camporeeEventsProvider.overrideWith((ref, id) async => events),
        // After any test program: the "now / next" group stays hidden.
        camporeeClockProvider.overrideWithValue(() => DateTime(2100)),
        camporeeEventAttachmentsProvider.overrideWith(
          (ref, eventId) async => [
            for (final event in events)
              if (event.camporeeEventId == eventId) ...event.attachments,
          ],
        ),
        camporeeLeaderboardProvider.overrideWith(
          (ref, id) async =>
              leaderboard ??
              const CamporeeLeaderboard(
                scopeType: 'local',
                camporeeId: 41,
                rows: [],
              ),
        ),
        camporeeScoreBreakdownProvider.overrideWith(
          (ref, id) async =>
              breakdown ??
              const CamporeeScoreBreakdown(
                scopeType: 'local',
                camporeeId: 41,
                visibility: 'full',
                sections: [],
              ),
        ),
        camporeeMembersProvider.overrideWith((ref, id) async {
          onMembersLoad();
          if (keepMembersLoading) return loading.future;
          if (failMembersOnce && !failed) {
            failed = true;
            throw Exception('socket');
          }
          return members;
        }),
        camporeeOrderOfferingsProvider.overrideWith(
          (ref, scope) async => const CamporeeOrderOfferingsCatalog(
            settings: CamporeeOrderSettings(ordersEnabled: false),
          ),
        ),
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
            home: const CamporeeDetailView(camporeeId: 41),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _openTab(WidgetTester tester, String label) async {
  final key = switch (label) {
    'Asistentes' => const Key('camporee-detail-tab-people'),
    'Eventos' => const Key('camporee-detail-tab-events'),
    'Agenda' => const Key('camporee-detail-tab-agenda'),
    _ => const Key('camporee-detail-tab-info'),
  };
  await tester.tap(find.byKey(key));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 220));
}

const _director = UserEntity(
  id: 'director-user',
  email: 'director@example.com',
  authorization: AuthorizationSnapshot(
    activeAssignmentId: 'active',
    capabilities: [
      'club.active_director',
      'club.operational_staff',
      'club.staff_mode',
    ],
    clubAssignments: [
      AuthorizationGrant(
        assignmentId: 'active',
        roleName: 'director',
        status: 'active',
        clubId: 8,
        sectionId: 12,
        clubTypeId: 2,
      ),
    ],
  ),
);

const _deputy = UserEntity(
  id: 'deputy-user',
  email: 'deputy@example.com',
  authorization: AuthorizationSnapshot(
    activeAssignmentId: 'active',
    capabilities: ['club.operational_staff', 'club.staff_mode'],
    clubAssignments: [
      AuthorizationGrant(
        assignmentId: 'active',
        roleName: 'deputy-director',
        status: 'active',
        clubId: 8,
        sectionId: 12,
        clubTypeId: 2,
      ),
    ],
  ),
);

final _scoredEvents = [
  _event(
    id: 27,
    title: 'Orden cerrado',
    day: 1,
    startsAt: '08:00',
    scoring: true,
    typeCode: 'scoring',
    typeName: 'Puntaje',
    category: 'competencia',
  ),
  _event(
    id: 28,
    title: 'Nudos',
    day: 1,
    startsAt: '10:00',
    scoring: true,
    typeCode: 'scoring',
    typeName: 'Puntaje',
    category: 'competencia',
  ),
];

CamporeeScoreBreakdown _breakdown({
  required String visibility,
  required List<CamporeeScoreBreakdownSection> sections,
}) =>
    CamporeeScoreBreakdown(
      scopeType: 'local',
      camporeeId: 41,
      visibility: visibility,
      sections: sections,
    );

CamporeeScoreBreakdownSection _breakdownSection(
  int sectionId,
  String club, {
  required double awarded,
  int? rank,
}) =>
    CamporeeScoreBreakdownSection(
      rank: rank,
      clubSectionId: sectionId,
      clubName: club,
      sectionName: 'Conquistadores',
      totalAwardedPoints: awarded,
      totalMaxPoints: 500,
      results: [
        CamporeeScoreBreakdownResult(
          camporeeEventId: 27,
          score: CamporeeOfficialScore(
            resultId: 'r-$sectionId',
            scoreStatus: 'scored',
            isNoShow: false,
            totalAwarded: awarded,
            totalMax: 500,
            rawAwarded: awarded,
            minimumAdjustment: 0,
            notes: 'Buena formación',
            evaluatorName: 'Ana Ruiz',
            submittedAt: DateTime.utc(2026, 11, 1, 12),
            items: const [
              CamporeeOfficialScoreItem(
                rubricId: 1,
                title: 'Uniforme',
                awardedPoints: 250,
                maxPoints: 300,
                notes: 'Falta pañoleta',
              ),
            ],
          ),
        ),
      ],
    );

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

// Relative to today: a past end date makes the view read-only.
final _camporeeStart = DateUtils.dateOnly(DateTime.now()).add(
  const Duration(days: 30),
);

final _camporee = Camporee(
  camporeeId: 41,
  name: 'Camporí Esperanza',
  startDate: _camporeeStart,
  endDate: _camporeeStart.add(const Duration(days: 3)),
  place: 'Valle Verde',
  registrationCost: 125,
  includesAdventurers: true,
  includesPathfinders: true,
  includesMasterGuides: false,
  active: true,
);

final _programEvents = [
  _event(
    id: 4,
    title: 'Fútbol recreativo',
    day: 2,
    startsAt: '16:00',
    typeCode: 'recreational',
    typeName: 'Recreativo',
    category: 'social',
  ),
  _event(
    id: 2,
    title: 'Orden cerrado',
    day: 1,
    startsAt: '09:00',
    scoring: true,
    typeCode: 'scoring',
    typeName: 'Puntaje',
    category: 'competencia',
  ),
  _event(
    id: 1,
    title: 'Culto de apertura',
    day: 1,
    startsAt: '07:00',
    typeCode: 'spiritual',
    typeName: 'Espiritual',
    category: 'espiritual',
  ),
  _event(
    id: 5,
    title: 'Tiempo de descanso',
    day: 2,
    startsAt: '12:00',
    typeCode: 'rest',
    typeName: 'Descanso',
  ),
  _event(
    id: 3,
    title: 'Nudos',
    day: 2,
    startsAt: '08:00',
    scoring: true,
    typeCode: 'scoring',
    typeName: 'Puntaje',
    category: 'competencia',
  ),
];

CamporeeEvent _event({
  required int id,
  required String title,
  required int day,
  String? startsAt,
  String? venueName,
  bool scoring = false,
  String typeCode = 'general',
  String typeName = 'General',
  String category = 'logistico',
  bool agendaVisible = true,
  List<CamporeeEventAttachment> attachments = const [],
}) {
  return CamporeeEvent(
    camporeeEventId: id,
    title: title,
    maxPoints: scoring ? 100 : 0,
    minPoints: 0,
    dayNumber: day,
    startsAt: startsAt,
    venueName: venueName,
    displayCategory: category,
    status: 'programado',
    participantsMode: 'count',
    scoringEnabled: scoring,
    eventTypeCode: typeCode,
    eventTypeName: typeName,
    agendaVisible: agendaVisible,
    attachments: attachments,
  );
}

CamporeeSectionRegistration _registration(
  CamporeeSectionRegistrationStatus status, {
  bool canEnroll = false,
}) {
  return CamporeeSectionRegistration(
    camporeeId: 41,
    clubId: 8,
    clubName: 'Club Orión',
    clubSectionId: 12,
    sectionName: 'Conquistadores',
    clubTypeId: 2,
    clubTypeName: 'Conquistadores',
    status: status,
    disposition: CamporeeSectionRegistrationDisposition.open,
    canEnroll: canEnroll,
    registeredAt:
        status.enablesParticipantsForTest ? DateTime(2026, 7, 12) : null,
    registeredBy: status.enablesParticipantsForTest
        ? const CamporeeSectionRegistrationActor(
            userId: 'director-1',
            displayName: 'Ana Directora',
          )
        : null,
  );
}

extension on CamporeeSectionRegistrationStatus {
  bool get enablesParticipantsForTest =>
      this == CamporeeSectionRegistrationStatus.registered ||
      this == CamporeeSectionRegistrationStatus.approved;
}
