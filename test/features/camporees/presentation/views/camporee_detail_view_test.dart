import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_offering.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/providers/camporee_orders_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_detail_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      find.text('Inscripción de la sección', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Miembros inscritos'), findsNothing);
    expect(memberLoads, 0);

    await _openTab(tester, 'Asistentes');

    expect(find.text('Miembros inscritos'), findsOneWidget);
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
    expect(find.text('Reintentar miembros'), findsOneWidget);
    expect(memberLoads, 1);

    await tester.tap(find.text('Reintentar miembros'));
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

  testWidgets('muestra clasificación oficial debajo de eventos',
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
      find.text('Clasificación'),
      400,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    expect(find.text('Clasificación'), findsOneWidget);
    expect(find.text('ACV'), findsOneWidget);
    expect(find.text('85 / 100'), findsOneWidget);
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
    expect(find.widgetWithText(AppBar, 'Camporí Esperanza'), findsOneWidget);
    expect(find.text('Camporí Esperanza'), findsWidgets);
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

    expect(find.text('Descripción', skipOffstage: false), findsNothing);
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

    expect(find.text('Descripción', skipOffstage: false), findsOneWidget);
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
    expect(find.text('Día 1'), findsOneWidget);
    expect(find.text('Día 2'), findsOneWidget);

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
    expect(find.text('Día 1'), findsNothing);
    expect(find.text('Agenda pendiente'), findsWidgets);
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
  Camporee? camporee,
  List<CamporeeMember> members = const [],
  List<CamporeeEvent> events = const [],
}) async {
  var failed = false;
  final loading = Completer<List<CamporeeMember>>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _TestAuthNotifier(user)),
        camporeeDetailProvider
            .overrideWith((ref, id) async => camporee ?? _camporee),
        camporeeSectionRegistrationProvider
            .overrideWith((ref, id) async => registration),
        camporeeEventsProvider.overrideWith((ref, id) async => events),
        camporeeLeaderboardProvider.overrideWith(
          (ref, id) async =>
              leaderboard ??
              const CamporeeLeaderboard(
                scopeType: 'local',
                camporeeId: 41,
                rows: [],
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
  await tester.pump(const Duration(milliseconds: 160));
}

const _director = UserEntity(
  id: 'director-user',
  email: 'director@example.com',
  authorization: AuthorizationSnapshot(
    activeAssignmentId: 'active',
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

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

final _camporee = Camporee(
  camporeeId: 41,
  name: 'Camporí Esperanza',
  startDate: DateTime(2026, 8, 15),
  endDate: DateTime(2026, 8, 18),
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
  );
}

CamporeeSectionRegistration _registration(
  CamporeeSectionRegistrationStatus status,
) {
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
    canEnroll: false,
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
