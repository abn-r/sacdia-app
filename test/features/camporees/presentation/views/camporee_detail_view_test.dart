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

    final registrationY =
        tester.getTopLeft(find.text('Inscripción de la sección')).dy;
    final membersY = tester.getTopLeft(find.text('Miembros inscritos')).dy;
    expect(registrationY, lessThan(membersY));
    expect(memberLoads, 0);
    expect(
      find.text(
        'La inscripción de participantes está bloqueada hasta que la sección esté registrada y habilitada.',
      ),
      findsOneWidget,
    );
    final enrollButton = tester.widget<SacButton>(
      find.widgetWithText(SacButton, 'Inscribir'),
    );
    expect(enrollButton.onPressed, isNull);
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
    expect(find.text('Inscribir participantes'), findsOneWidget);
    final enrollButton = tester.widget<SacButton>(
      find.widgetWithText(SacButton, 'Inscribir'),
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
    expect(find.text('Inscribir participantes'), findsNothing);
    final enrollButton = tester.widget<SacButton>(
      find.widgetWithText(SacButton, 'Inscribir'),
    );
    expect(enrollButton.onPressed, isNull);
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

    await tester.ensureVisible(find.text('Clasificación'));
    await tester.pump();
    expect(find.text('Clasificación'), findsOneWidget);
    expect(find.text('ACV'), findsOneWidget);
    expect(find.text('85 / 100'), findsOneWidget);
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
}) async {
  var failed = false;
  final loading = Completer<List<CamporeeMember>>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _TestAuthNotifier(user)),
        camporeeDetailProvider.overrideWith((ref, id) async => _camporee),
        camporeeSectionRegistrationProvider
            .overrideWith((ref, id) async => registration),
        camporeeEventsProvider
            .overrideWith((ref, id) async => const <CamporeeEvent>[]),
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
          return const <CamporeeMember>[];
        }),
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
  await tester.pump(const Duration(milliseconds: 50));
  await tester.drag(find.byType(ListView), const Offset(0, -900));
  await tester.pump(const Duration(milliseconds: 500));
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
