import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_register_member_view.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_participant_access_gate.dart';
import 'package:sacdia_app/features/insurance/presentation/providers/insurance_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  test('loading con dato anterior sigue bloqueado fail-closed', () {
    final previous = AsyncData(
      _registration(CamporeeSectionRegistrationStatus.registered),
    );
    final refreshing = const AsyncLoading<CamporeeSectionRegistration>()
        .copyWithPrevious(previous);

    expect(camporeeParticipantsAreEnabled(previous), isTrue);
    expect(camporeeParticipantsAreEnabled(refreshing), isFalse);
  });

  for (final status in [
    CamporeeSectionRegistrationStatus.notEnrolled,
    CamporeeSectionRegistrationStatus.pendingApproval,
    CamporeeSectionRegistrationStatus.rejected,
    CamporeeSectionRegistrationStatus.cancelled,
    CamporeeSectionRegistrationStatus.unknown,
  ]) {
    testWidgets('$status bloquea la vista directa sin cargar participantes',
        (tester) async {
      var insuranceLoads = 0;
      var registeredIdsLoads = 0;

      await _pumpView(
        tester,
        registration: _registration(status),
        onInsuranceLoad: () => insuranceLoads += 1,
        onRegisteredIdsLoad: () => registeredIdsLoads += 1,
      );

      expect(find.text('Seleccionar miembros'), findsNothing);
      expect(find.text('Registrar 0 miembros'), findsNothing);
      expect(insuranceLoads, 0);
      expect(registeredIdsLoads, 0);
      expect(
        find.text(
          'La inscripción de participantes está bloqueada hasta que la sección esté registrada y habilitada.',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('loading bloquea fail-closed y anuncia la validación',
      (tester) async {
    final registrationCompleter = Completer<CamporeeSectionRegistration>();
    var insuranceLoads = 0;
    var registeredIdsLoads = 0;

    await _pumpView(
      tester,
      registrationFuture: registrationCompleter.future,
      onInsuranceLoad: () => insuranceLoads += 1,
      onRegisteredIdsLoad: () => registeredIdsLoads += 1,
    );

    expect(find.text('Seleccionar miembros'), findsNothing);
    expect(insuranceLoads, 0);
    expect(registeredIdsLoads, 0);
    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Consultando inscripción de sección',
      ),
    );
    expect(semantics.properties.liveRegion, isTrue);
  });

  testWidgets('error bloquea datos y retry vuelve a consultar el gate',
      (tester) async {
    var registrationLoads = 0;
    var insuranceLoads = 0;
    var registeredIdsLoads = 0;

    await _pumpView(
      tester,
      registrationLoader: () async {
        registrationLoads += 1;
        if (registrationLoads == 1) throw Exception('socket');
        return _registration(
          CamporeeSectionRegistrationStatus.pendingApproval,
        );
      },
      onInsuranceLoad: () => insuranceLoads += 1,
      onRegisteredIdsLoad: () => registeredIdsLoads += 1,
    );

    expect(find.text('No pudimos consultar la inscripción.'), findsOneWidget);
    expect(find.textContaining('socket'), findsNothing);
    expect(insuranceLoads, 0);
    expect(registeredIdsLoads, 0);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(registrationLoads, 2);
    expect(find.text('Pendiente de aprobación'), findsOneWidget);
    expect(insuranceLoads, 0);
    expect(registeredIdsLoads, 0);
  });

  for (final status in [
    CamporeeSectionRegistrationStatus.registered,
    CamporeeSectionRegistrationStatus.approved,
  ]) {
    testWidgets('$status habilita el formulario y sus fuentes de datos',
        (tester) async {
      var insuranceLoads = 0;
      var registeredIdsLoads = 0;

      await _pumpView(
        tester,
        registration: _registration(status),
        onInsuranceLoad: () => insuranceLoads += 1,
        onRegisteredIdsLoad: () => registeredIdsLoads += 1,
      );

      expect(find.text('Seleccionar miembros'), findsOneWidget);
      expect(find.text('Registrar 0 miembros'), findsOneWidget);
      expect(insuranceLoads, 1);
      expect(registeredIdsLoads, 1);
    });
  }
}

Future<void> _pumpView(
  WidgetTester tester, {
  CamporeeSectionRegistration? registration,
  Future<CamporeeSectionRegistration>? registrationFuture,
  Future<CamporeeSectionRegistration> Function()? registrationLoader,
  required VoidCallback onInsuranceLoad,
  required VoidCallback onRegisteredIdsLoad,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        camporeeSectionRegistrationProvider.overrideWith((ref, id) async {
          if (registrationLoader != null) return registrationLoader();
          if (registrationFuture != null) return registrationFuture;
          return registration!;
        }),
        membersInsuranceProvider.overrideWith((ref) async {
          onInsuranceLoad();
          return const [];
        }),
        camporeeRegisteredUserIdsProvider.overrideWith((ref, id) async {
          onRegisteredIdsLoad();
          return const <String>{};
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
            home: const CamporeeRegisterMemberView(camporeeId: 41),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
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
