import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_section_registration_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('director habilitado ve Inscribir mi sección', (tester) async {
    await _pumpPanel(tester, registration: _registration(canEnroll: true));
    expect(find.text('Inscribir mi sección'), findsOneWidget);
  });

  testWidgets('subdirector sin permiso recibe orientación y nunca ve el CTA',
      (tester) async {
    await _pumpPanel(tester, registration: _registration(canEnroll: false));

    expect(find.text('Inscribir mi sección'), findsNothing);
    expect(
      find.text(
          'Solo el director de la sección puede realizar la inscripción.'),
      findsOneWidget,
    );
  });

  testWidgets('pendiente explica la aprobación y bloquea participantes',
      (tester) async {
    await _pumpPanel(
      tester,
      registration: _registration(
        status: CamporeeSectionRegistrationStatus.pendingApproval,
      ),
    );

    expect(find.text('Pendiente de aprobación'), findsOneWidget);
    expect(
      find.text(
          'Podrás inscribir participantes cuando la solicitud sea aprobada.'),
      findsOneWidget,
    );
    expect(find.text('Inscribir participantes'), findsNothing);
  });

  for (final status in [
    CamporeeSectionRegistrationStatus.registered,
    CamporeeSectionRegistrationStatus.approved,
  ]) {
    testWidgets('$status muestra actor, fecha y acción de participantes',
        (tester) async {
      var participantTaps = 0;
      await _pumpPanel(
        tester,
        registration: _registration(status: status),
        onManageParticipants: () => participantTaps += 1,
      );

      expect(find.textContaining('Ana Directora'), findsOneWidget);
      expect(find.text('Inscribir participantes'), findsOneWidget);
      await tester.tap(find.text('Inscribir participantes'));
      expect(participantTaps, 1);
    });
  }

  testWidgets('loading reserva la misma altura mínima que el contenido',
      (tester) async {
    await _pumpPanel(tester, registrationAsync: const AsyncLoading());
    final loadingHeight = tester
        .getSize(
          find.byKey(const Key('camporee-section-registration-panel')),
        )
        .height;

    await _pumpPanel(tester, registration: _registration(canEnroll: true));
    final dataHeight = tester
        .getSize(
          find.byKey(const Key('camporee-section-registration-panel')),
        )
        .height;

    expect(loadingHeight, greaterThanOrEqualTo(220));
    expect(dataHeight, greaterThanOrEqualTo(220));
  });

  testWidgets('error de red ofrece reintento accesible', (tester) async {
    var retries = 0;
    await _pumpPanel(
      tester,
      registrationAsync: AsyncError(Exception('socket'), StackTrace.empty),
      onRetry: () => retries += 1,
    );

    expect(find.text('No pudimos consultar la inscripción.'), findsOneWidget);
    final retry = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Reintentar consulta de inscripción',
    );
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    expect(retries, 1);
    expect(find.textContaining('socket'), findsNothing);
  });

  testWidgets('estados cerrados son claros y no muestran acciones',
      (tester) async {
    final cases = <CamporeeSectionRegistration, String>{
      _registration(
        disposition: CamporeeSectionRegistrationDisposition.notOpenYet,
      ): 'Inscripciones aún no disponibles',
      _registration(
        disposition: CamporeeSectionRegistrationDisposition.manuallyFrozen,
      ): 'Inscripciones pausadas',
      _registration(status: CamporeeSectionRegistrationStatus.rejected):
          'Inscripción rechazada',
      _registration(status: CamporeeSectionRegistrationStatus.cancelled):
          'Inscripción cancelada',
    };

    for (final entry in cases.entries) {
      await _pumpPanel(tester, registration: entry.key);
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('Inscribir mi sección'), findsNothing);
      expect(find.text('Inscribir participantes'), findsNothing);
    }
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  CamporeeSectionRegistration? registration,
  AsyncValue<CamporeeSectionRegistration>? registrationAsync,
  VoidCallback? onRetry,
  VoidCallback? onManageParticipants,
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('es')],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('es'),
      startLocale: const Locale('es'),
      child: ProviderScope(
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: CamporeeSectionRegistrationPanel(
                  registrationAsync:
                      registrationAsync ?? AsyncData(registration!),
                  onEnroll: () {},
                  onRetry: onRetry ?? () {},
                  onManageParticipants: onManageParticipants ?? () {},
                ),
              ),
            ),
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

CamporeeSectionRegistration _registration({
  CamporeeSectionRegistrationStatus status =
      CamporeeSectionRegistrationStatus.notEnrolled,
  CamporeeSectionRegistrationDisposition disposition =
      CamporeeSectionRegistrationDisposition.open,
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
    disposition: disposition,
    canEnroll: canEnroll,
    registeredAt: status == CamporeeSectionRegistrationStatus.registered ||
            status == CamporeeSectionRegistrationStatus.approved
        ? DateTime(2026, 7, 12, 10, 30)
        : null,
    registeredBy: status == CamporeeSectionRegistrationStatus.registered ||
            status == CamporeeSectionRegistrationStatus.approved
        ? const CamporeeSectionRegistrationActor(
            userId: 'director-1',
            displayName: 'Ana Directora',
          )
        : null,
  );
}
