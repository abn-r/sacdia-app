import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_category.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_item.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_program.dart';
import 'package:sacdia_app/features/materials/presentation/providers/product_detail_provider.dart';
import 'package:sacdia_app/features/materials/presentation/views/product_detail_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

MaterialItem _item(String title) => MaterialItem(
      id: 'p1',
      sku: 'SKU-1',
      title: title,
      category: const MaterialCategory(
        id: 'cat-1',
        slug: 'material',
        label: 'Material',
        sortOrder: 0,
      ),
      programa: const MaterialProgram(id: 1, label: 'Aventureros'),
      priceCentavos: 7000,
      stock: 10,
      active: true,
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpProduct(WidgetTester tester, String title) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productDetailProvider('p1').overrideWith((ref) async => _item(title)),
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
              home: const ProductDetailView(productId: 'p1'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  for (final title in ['Pañoleta', 'Cuadernillo']) {
    testWidgets('add-to-cart snackbar is gender neutral for "$title"',
        (tester) async {
      await pumpProduct(tester, title);

      await tester.tap(find.text('Agregar al carrito'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Se agregó $title al carrito'), findsOneWidget);
      expect(find.textContaining('agregado'), findsNothing);
    });
  }

  test('every locale keeps the {title} placeholder', () {
    for (final locale in ['es', 'en', 'fr', 'pt-BR']) {
      final json = jsonDecode(
        File('assets/translations/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final value = ((json['materials'] as Map)['product']
          as Map)['added_snackbar'] as String;
      expect(value, contains('{title}'), reason: locale);
    }
  });
}
