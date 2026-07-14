import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_section_registration_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('confirmación es contextual e inmutable', (tester) async {
    await _pumpSheet(tester, onConfirm: () async => false);

    expect(find.text('Club Orión'), findsOneWidget);
    expect(find.text('Conquistadores'), findsOneWidget);
    expect(find.text('Camporí Esperanza'), findsOneWidget);
    expect(find.textContaining('125'), findsOneWidget);
    expect(find.text('Fecha límite'), findsOneWidget);
    expect(
      find.text('Registrarás esta inscripción como director.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('club_section_id'), findsNothing);
  });

  testWidgets(
      'doble toque durante loading confirma una sola vez y cierra al éxito',
      (tester) async {
    final result = Completer<bool>();
    var calls = 0;
    await _pumpSheet(
      tester,
      onConfirm: () {
        calls += 1;
        return result.future;
      },
    );

    final confirm =
        find.widgetWithText(ElevatedButton, 'Confirmar inscripción');
    await tester.tap(confirm);
    await tester.tap(confirm);
    await tester.pump();

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    result.complete(true);
    await tester.pumpAndSettle();

    expect(find.byType(CamporeeSectionRegistrationSheet), findsNothing);
    expect(find.text('Sección inscrita correctamente.'), findsOneWidget);
  });

  testWidgets('fallo permanece abierto y permite reintentar', (tester) async {
    var calls = 0;
    await _pumpSheet(
      tester,
      onConfirm: () async {
        calls += 1;
        return calls > 1;
      },
    );

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Confirmar inscripción'),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pudimos inscribir la sección.'), findsOneWidget);
    expect(find.text('Reintentar inscripción'), findsOneWidget);

    await tester.tap(find.text('Reintentar inscripción'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byType(CamporeeSectionRegistrationSheet), findsNothing);
  });
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required Future<bool> Function() onConfirm,
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
              body: Builder(
                builder: (sheetContext) => ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: sheetContext,
                    isScrollControlled: true,
                    builder: (_) => CamporeeSectionRegistrationSheet(
                      camporee: _camporee,
                      registration: _registration,
                      onConfirm: onConfirm,
                    ),
                  ),
                  child: const Text('Abrir'),
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
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
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

const _registration = CamporeeSectionRegistration(
  camporeeId: 41,
  clubId: 8,
  clubName: 'Club Orión',
  clubSectionId: 12,
  sectionName: 'Conquistadores',
  clubTypeId: 2,
  clubTypeName: 'Conquistadores',
  status: CamporeeSectionRegistrationStatus.notEnrolled,
  disposition: CamporeeSectionRegistrationDisposition.open,
  canEnroll: true,
);
