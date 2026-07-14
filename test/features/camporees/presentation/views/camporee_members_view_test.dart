import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_member.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_members_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final status in [
    CamporeeSectionRegistrationStatus.notEnrolled,
    CamporeeSectionRegistrationStatus.pendingApproval,
    CamporeeSectionRegistrationStatus.rejected,
    CamporeeSectionRegistrationStatus.cancelled,
    CamporeeSectionRegistrationStatus.unknown,
  ]) {
    testWidgets('$status bloquea la lista y todas las altas', (tester) async {
      var memberLoads = 0;

      await _pumpView(
        tester,
        registration: _registration(status),
        onMembersLoad: () => memberLoads += 1,
      );

      expect(memberLoads, 0);
      expect(find.text('Inscribir primer miembro'), findsNothing);
      expect(find.byTooltip('Inscribir miembro'), findsNothing);
      expect(
        find.text(
          'La inscripción de participantes está bloqueada hasta que la sección esté registrada y habilitada.',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('loading bloquea la lista sin exponer altas', (tester) async {
    final registrationCompleter = Completer<CamporeeSectionRegistration>();
    var memberLoads = 0;

    await _pumpView(
      tester,
      registrationFuture: registrationCompleter.future,
      onMembersLoad: () => memberLoads += 1,
    );

    expect(memberLoads, 0);
    expect(find.byTooltip('Inscribir miembro'), findsNothing);
    expect(find.text('Inscribir primer miembro'), findsNothing);
  });

  testWidgets('error reintenta sólo el gate antes de cargar miembros',
      (tester) async {
    var registrationLoads = 0;
    var memberLoads = 0;

    await _pumpView(
      tester,
      registrationLoader: () async {
        registrationLoads += 1;
        if (registrationLoads == 1) throw Exception('socket');
        return _registration(
          CamporeeSectionRegistrationStatus.pendingApproval,
        );
      },
      onMembersLoad: () => memberLoads += 1,
    );

    expect(find.text('No pudimos consultar la inscripción.'), findsOneWidget);
    expect(memberLoads, 0);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(registrationLoads, 2);
    expect(memberLoads, 0);
    expect(find.text('Pendiente de aprobación'), findsOneWidget);
  });

  for (final status in [
    CamporeeSectionRegistrationStatus.registered,
    CamporeeSectionRegistrationStatus.approved,
  ]) {
    testWidgets('$status carga miembros y conserva las altas', (tester) async {
      var memberLoads = 0;

      await _pumpView(
        tester,
        registration: _registration(status),
        onMembersLoad: () => memberLoads += 1,
      );

      expect(memberLoads, 1);
      expect(find.byTooltip('Inscribir miembro'), findsOneWidget);
      expect(find.text('Inscribir primer miembro'), findsOneWidget);
    });
  }
}

Future<void> _pumpView(
  WidgetTester tester, {
  CamporeeSectionRegistration? registration,
  Future<CamporeeSectionRegistration>? registrationFuture,
  Future<CamporeeSectionRegistration> Function()? registrationLoader,
  required VoidCallback onMembersLoad,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        camporeeSectionRegistrationProvider.overrideWith((ref, id) async {
          if (registrationLoader != null) return registrationLoader();
          if (registrationFuture != null) return registrationFuture;
          return registration!;
        }),
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
            home: const CamporeeMembersView(
              camporeeId: 41,
              camporeeName: 'Camporí Esperanza',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
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
  );
}
