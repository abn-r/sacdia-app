import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sacdia_app/features/activities/presentation/providers/activities_providers.dart';
import 'package:sacdia_app/features/activities/presentation/views/create_activity_view.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/shared/models/catalogs/activity_type_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../support/riverpod_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> translations;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es');
    await EasyLocalization.ensureInitialized();
    translations = jsonDecode(
      await File('assets/translations/es.json').readAsString(),
    ) as Map<String, dynamic>;
  });

  testWidgets(
    'submitting from the bottom still validates the off-screen name field',
    (tester) async {
      // Short viewport so the name field scrolls off-screen.
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        testProviderScope(
          overrides: [
            activityTypesProvider.overrideWith(
              (ref) async => const [
                ActivityTypeModel(
                    activityTypeId: 1, code: 'R', name: 'Regular'),
              ],
            ),
            currentEcclesiasticalYearProvider.overrideWith((ref) async => null),
            clubContextProvider.overrideWith((ref) async => null),
            clubSectionsForActivityProvider.overrideWith((ref) async => []),
          ],
          child: EasyLocalization(
            supportedLocales: const [Locale('es')],
            path: 'assets/translations',
            fallbackLocale: const Locale('es'),
            assetLoader: _TestAssetLoader(translations),
            child: Builder(
              builder: (context) => MaterialApp(
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                home: const CreateActivityView(clubId: 1, clubSectionId: 2),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.text('Crear Actividad');
      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Nombre de la actividad'), findsNothing,
          reason: 'name field label should be scrolled away');

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('El nombre es requerido'), findsOneWidget);
    },
  );

  testWidgets('the date is required: saving without one flags the field',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(translations));
    await tester.pumpAndSettle();

    final dateLabel = find.text('Fecha *');
    await tester.scrollUntilVisible(
      dateLabel,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Elige la fecha de la actividad'), findsNothing);

    final saveButton = find.text('Crear Actividad');
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Elige la fecha de la actividad'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Elige la fecha de la actividad'), findsOneWidget);
  });
}

Widget _app(Map<String, dynamic> translations) => testProviderScope(
      overrides: [
        activityTypesProvider.overrideWith(
          (ref) async => const [
            ActivityTypeModel(activityTypeId: 1, code: 'R', name: 'Regular'),
          ],
        ),
        currentEcclesiasticalYearProvider.overrideWith((ref) async => null),
        clubContextProvider.overrideWith((ref) async => null),
        clubSectionsForActivityProvider.overrideWith((ref) async => []),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        fallbackLocale: const Locale('es'),
        assetLoader: _TestAssetLoader(translations),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const CreateActivityView(clubId: 1, clubSectionId: 2),
          ),
        ),
      ),
    );

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader(this.translations);

  final Map<String, dynamic> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return translations;
  }
}
