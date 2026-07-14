import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_member.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_detail_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnauthenticatedNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => null;
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
    final enrollButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Inscribir'),
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
    final enrollButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Inscribir'),
    );
    expect(enrollButton.onPressed, isNotNull);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required CamporeeSectionRegistration registration,
  required VoidCallback onMembersLoad,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_UnauthenticatedNotifier.new),
        camporeeDetailProvider.overrideWith((ref, id) async => _camporee),
        camporeeSectionRegistrationProvider
            .overrideWith((ref, id) async => registration),
        camporeeMembersProvider.overrideWith((ref, id) async {
          onMembersLoad();
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
