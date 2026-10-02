import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/units/domain/entities/unit.dart';
import 'package:sacdia_app/features/units/presentation/views/unit_form_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets(
    'Cancelar y Crear comparten el ancho en nueva unidad',
    (tester) async {
      await _openSheet(tester);
      expect(find.text('Nueva Unidad'), findsOneWidget);
      _expectEqualActions(tester, 'Crear');
    },
  );

  testWidgets(
    'Cancelar y Guardar comparten el ancho al editar',
    (tester) async {
      await _openSheet(
        tester,
        unit: const Unit(
          id: 7,
          name: 'Águilas',
          type: 'Conquistadores',
          memberCount: 4,
        ),
      );
      expect(find.text('Editar Unidad'), findsOneWidget);
      _expectEqualActions(tester, 'Guardar');
    },
  );
}

void _expectEqualActions(WidgetTester tester, String primaryLabel) {
  final cancel = find.widgetWithText(SacButton, 'Cancelar');
  final primary = find.widgetWithText(SacButton, primaryLabel);
  expect(cancel, findsOneWidget);
  expect(primary, findsOneWidget);

  final cancelExpanded = tester.element(_expandedOf(cancel));
  final primaryExpanded = tester.element(_expandedOf(primary));
  expect((cancelExpanded.widget as Expanded).flex, 1);
  expect((primaryExpanded.widget as Expanded).flex, 1);
  expect(
    cancelExpanded.renderObject!.parent,
    primaryExpanded.renderObject!.parent,
  );

  final cancelRect = tester.getRect(cancel);
  final primaryRect = tester.getRect(primary);
  expect(cancelRect.width, closeTo(primaryRect.width, 1));
  expect(cancelRect.height, closeTo(primaryRect.height, 1));
  expect(primaryRect.left - cancelRect.right, closeTo(12, 1));
  expect(cancelRect.right, lessThan(primaryRect.left));

  final label = tester.renderObject<RenderParagraph>(find.text('Cancelar'));
  expect(label.text.toPlainText(), 'Cancelar');
  // En un teléfono de 390 pt el reparto 1:2 dejaba ~65 px para el texto
  // y "Cancelar" (~70 px en SF Pro) se cortaba. El reparto igual deja más.
  expect(label.constraints.maxWidth, greaterThan(90));
}

Finder _expandedOf(Finder button) {
  return find.ancestor(of: button, matching: find.byType(Expanded)).first;
}

Future<void> _openSheet(WidgetTester tester, {Unit? unit}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clubContextProvider.overrideWith((ref) async => null),
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
            home: _OpenSheet(unit: unit),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.tap(find.text('Abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _OpenSheet extends ConsumerWidget {
  const _OpenSheet({this.unit});

  final Unit? unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: TextButton(
        onPressed: () => showUnitFormSheet(
          context: context,
          ref: ref,
          unit: unit,
        ),
        child: const Text('Abrir'),
      ),
    );
  }
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}
