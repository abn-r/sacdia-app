import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/club/domain/entities/club_info.dart';
import 'package:sacdia_app/features/club/presentation/providers/club_providers.dart';
import 'package:sacdia_app/features/club/presentation/views/club_edit_view.dart';
import 'package:sacdia_app/features/club/presentation/views/club_view.dart';
import 'package:sacdia_app/features/club/presentation/widgets/club_profile_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/riverpod_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('missingFields', () {
    test('lists every empty field in display order', () {
      expect(_section().missingFields, [
        ClubField.location,
        ClubField.phone,
        ClubField.email,
        ClubField.website,
      ]);
    });

    test('blank strings count as missing; an address alone is a location', () {
      final section =
          _section(address: 'Calle 5', phone: '  ', email: 'a@b.co');
      expect(section.missingFields, [ClubField.phone, ClubField.website]);
    });
  });

  group('withClubLocation', () {
    const club = ClubInfo(
      id: 'club-1',
      name: 'Halcones',
      active: true,
      lat: 19.19,
      long: -96.13,
    );

    test('uses the club coordinates when the section has none', () {
      final shown = _section(phone: '5551234').withClubLocation(club);
      expect(shown.lat, 19.19);
      expect(shown.long, -96.13);
      expect(shown.phone, '5551234');
      expect(shown.missingFields, isNot(contains(ClubField.location)));
    });

    test('keeps the section coordinates when it has them', () {
      final section = ClubSection(
        id: 7,
        mainClubId: 'club-1',
        clubTypeId: 2,
        clubTypeName: 'Conquistadores',
        lat: 20.5,
        long: -97.1,
        active: true,
      );
      final shown = section.withClubLocation(club);
      expect(shown.lat, 20.5);
      expect(shown.long, -97.1);
    });

    test('no club or club without coordinates changes nothing', () {
      final section = _section();
      expect(section.withClubLocation(null), same(section));
      expect(
        section.withClubLocation(
          const ClubInfo(id: 'club-1', name: 'Halcones', active: true),
        ),
        same(section),
      );
    });
  });

  group('ClubEditView prefill', () {
    testWidgets('loads the section values into the fields', (tester) async {
      await _pumpEditor(tester, section: _fullSection);

      expect(find.text('Av. Juárez 10'), findsOneWidget);
      expect(find.text('+52 55 1234 5678'), findsOneWidget);
      expect(find.text('club@halcones.mx'), findsOneWidget);
      expect(find.text('https://halcones.mx'), findsOneWidget);
    });

    testWidgets('starts the address with the club location', (tester) async {
      await _pumpEditor(
        tester,
        section: _section(),
        clubLat: 19.192313,
        clubLong: -96.130462,
      );

      // No geocoder in tests: the coordinates are the label.
      expect(find.text('19.19231, -96.13046'), findsOneWidget);
      TextButton save() =>
          tester.widget(find.byKey(const ValueKey('club-edit-save')));
      expect(save().onPressed, isNull);
    });
  });

  group('member', () {
    testWidgets('sees the ficha with actionable rows and no edit affordances',
        (tester) async {
      await _pump(tester, section: _fullSection, canEdit: false);

      expect(find.text('Halcones'), findsOneWidget);
      expect(find.text('Club de Conquistadores'), findsOneWidget);
      expect(find.text('Av. Juárez 10'), findsOneWidget);
      expect(find.text('+52 55 1234 5678'), findsOneWidget);
      expect(find.text('club@halcones.mx'), findsOneWidget);
      expect(find.text('https://halcones.mx'), findsOneWidget);

      expect(find.byKey(const ValueKey('club-edit-action')), findsNothing);
      expect(find.byKey(const ValueKey('club-missing-prompt')), findsNothing);
      expect(find.text('Sin registrar'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('never sees empty fields', (tester) async {
      await _pump(tester, section: _section(phone: '5551234'), canEdit: false);

      expect(find.byKey(const ValueKey('club-row-phone')), findsOneWidget);
      expect(find.byKey(const ValueKey('club-row-email')), findsNothing);
      expect(find.byKey(const ValueKey('club-row-website')), findsNothing);
      expect(find.byKey(const ValueKey('club-group-location')), findsNothing);
      expect(find.text('Sin registrar'), findsNothing);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('gets a note when the club registered nothing', (tester) async {
      await _pump(tester, section: _section(), canEdit: false);

      expect(find.byKey(const ValueKey('club-no-public-data')), findsOneWidget);
      expect(find.byKey(const ValueKey('club-group-contact')), findsNothing);
    });
  });

  group('director', () {
    testWidgets('sees «Editar», the missing-data prompt and «Sin registrar»',
        (tester) async {
      await _pump(tester, section: _section(phone: '5551234'), canEdit: true);

      expect(find.byKey(const ValueKey('club-edit-action')), findsOneWidget);
      expect(find.text('Faltan 3 datos del club'), findsOneWidget);
      expect(find.text('Sin registrar'), findsNWidgets(3));
      expect(find.byKey(const ValueKey('club-group-location')), findsOneWidget);
    });

    testWidgets('no prompt when everything is registered', (tester) async {
      await _pump(tester, section: _fullSection, canEdit: true);

      expect(find.byKey(const ValueKey('club-missing-prompt')), findsNothing);
      expect(find.text('Sin registrar'), findsNothing);
    });

    testWidgets('«Completar» opens the editor; «Guardar» waits for a change',
        (tester) async {
      await _pump(tester, section: _section(phone: '5551234'), canEdit: true);

      await tester.tap(find.byKey(const ValueKey('club-missing-complete')));
      await tester.pumpAndSettle();

      expect(find.byType(ClubEditView), findsOneWidget);
      expect(find.text('Editar club'), findsOneWidget);
      TextButton save() =>
          tester.widget(find.byKey(const ValueKey('club-edit-save')));
      expect(save().onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'club@ejemplo.com'),
        'hola@halcones.mx',
      );
      await tester.pump();
      expect(save().onPressed, isNotNull);
    });

    testWidgets('cancel with changes asks before discarding', (tester) async {
      await _pump(tester, section: _section(phone: '5551234'), canEdit: true);

      await tester.tap(find.byKey(const ValueKey('club-edit-action')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'club@ejemplo.com'),
        'hola@halcones.mx',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('club-edit-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Cambios sin guardar'), findsOneWidget);

      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(find.byType(ClubEditView), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('club-edit-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(ClubEditView), findsNothing);
      expect(find.byType(ClubView), findsOneWidget);
    });

    testWidgets('cancel without changes closes right away', (tester) async {
      await _pump(tester, section: _fullSection, canEdit: true);

      await tester.tap(find.byKey(const ValueKey('club-edit-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('club-edit-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Cambios sin guardar'), findsNothing);
      expect(find.byType(ClubEditView), findsNothing);
    });
  });
}

ClubSection _section({
  String? address,
  String? phone,
  String? email,
  String? website,
}) =>
    ClubSection(
      id: 7,
      mainClubId: 'club-1',
      clubTypeId: 2,
      clubTypeName: 'Conquistadores',
      address: address,
      phone: phone,
      email: email,
      website: website,
      active: true,
    );

final _fullSection = _section(
  address: 'Av. Juárez 10',
  phone: '+52 55 1234 5678',
  email: 'club@halcones.mx',
  website: 'https://halcones.mx',
);

Future<void> _pump(
  WidgetTester tester, {
  required ClubSection section,
  required bool canEdit,
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
        Locale('fr'),
        Locale('pt', 'BR'),
      ],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('es'),
      startLocale: const Locale('es'),
      child: testProviderScope(
        overrides: [
          currentClubSectionProvider.overrideWith((ref) async => section),
          canEditClubProvider.overrideWith((ref) async => canEdit),
          clubInfoProvider.overrideWith(
            (ref, id) async => ClubInfo(id: id, name: 'Halcones', active: true),
          ),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const ClubView(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required ClubSection section,
  double? clubLat,
  double? clubLong,
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
        Locale('fr'),
        Locale('pt', 'BR'),
      ],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('es'),
      startLocale: const Locale('es'),
      child: testProviderScope(
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: ClubEditView(
              section: section,
              clubLat: clubLat,
              clubLong: clubLong,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
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
