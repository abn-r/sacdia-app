import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_category.dart';
import 'package:sacdia_app/features/finances/presentation/providers/finances_providers.dart';
import 'package:sacdia_app/features/finances/presentation/views/add_transaction_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> translations;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting('es');
    translations = jsonDecode(
      await File('assets/translations/es.json').readAsString(),
    ) as Map<String, dynamic>;
  });

  Future<void> pumpSheet(
    WidgetTester tester,
    List<FinanceCategory> categories,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeCategoriesProvider.overrideWith((ref) async => categories),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          fallbackLocale: const Locale('es'),
          assetLoader: _TestAssetLoader(translations),
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: const Scaffold(body: AddTransactionSheet()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows a money icon and only categories compatible with the movement type',
    (tester) async {
      await pumpSheet(tester, const [
        FinanceCategory(id: 1, name: 'Cuotas', typeCode: 0),
        FinanceCategory(id: 2, name: 'Materiales', typeCode: 1),
      ]);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is HugeIcon &&
              widget.icon == HugeIcons.strokeRoundedMoney01,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Selecciona una categoría'));
      await tester.pumpAndSettle();

      expect(find.text('Cuotas'), findsOneWidget);
      expect(find.text('Materiales'), findsNothing);

      await tester.tap(find.text('Cuotas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Egreso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selecciona una categoría'));
      await tester.pumpAndSettle();

      expect(find.text('Cuotas'), findsNothing);
      expect(find.text('Materiales'), findsOneWidget);
    },
  );
}

class _TestAssetLoader extends AssetLoader {
  final Map<String, dynamic> translations;

  const _TestAssetLoader(this.translations);

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return translations;
  }
}
