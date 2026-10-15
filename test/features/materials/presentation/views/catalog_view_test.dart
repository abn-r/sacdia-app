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
import 'package:sacdia_app/features/materials/presentation/providers/catalog_provider.dart';
import 'package:sacdia_app/features/materials/presentation/providers/categories_provider.dart';
import 'package:sacdia_app/features/materials/presentation/providers/programs_provider.dart';
import 'package:sacdia_app/features/materials/presentation/views/catalog_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _category = MaterialCategory(
  id: 'cat-1',
  slug: 'material',
  label: 'Material',
  sortOrder: 0,
);

const _programAv = MaterialProgram(id: 1, label: 'Aventureros');
const _programCq = MaterialProgram(id: 2, label: 'Conquistadores');

MaterialItem _item({
  required String id,
  required String title,
  required MaterialProgram programa,
}) {
  return MaterialItem(
    id: id,
    sku: id,
    title: title,
    category: _category,
    programa: programa,
    priceCentavos: 7000,
    stock: 10,
    active: true,
  );
}

class _TestCatalogNotifier extends CatalogNotifier {
  @override
  Future<CatalogState> build(CatalogQuery query) async {
    if (query.cat == _category.slug) {
      return const CatalogState(
        errorMessage: 'Sin conexión con el servidor.',
      );
    }
    if (query.cat == _category.id) {
      return CatalogState(
        items: [
          _item(id: 'by-cat', title: 'Insignia Guía', programa: _programCq),
        ],
      );
    }
    if (query.programaId != null) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return CatalogState(
        items: [
          _item(id: 'av', title: 'Pañoleta', programa: _programAv),
        ],
      );
    }
    return CatalogState(
      items: [
        _item(id: 'all', title: 'Cuadernillo Amigo', programa: _programCq),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpCatalog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(
            (ref) async => const [_programAv, _programCq],
          ),
          categoriesProvider.overrideWith(
            (ref) async => const [_category],
          ),
          catalogProvider.overrideWith(_TestCatalogNotifier.new),
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
              home: const CatalogView(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('CatalogView', () {
    testWidgets(
        'should keep previous product visible while the next query loads',
        (tester) async {
      await pumpCatalog(tester);
      await tester.pump();

      expect(find.text('Cuadernillo Amigo'), findsOneWidget);
      expect(find.text('Para qué club'), findsOneWidget);
      expect(find.text('Todos los clubes'), findsOneWidget);
      expect(find.text('Categoría'), findsOneWidget);
      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThanOrEqualTo(44),
      );

      await tester.tap(find.text('Aventureros'));
      await tester.pump();

      expect(find.text('Cuadernillo Amigo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('Pañoleta'), findsOneWidget);
    });

    testWidgets('should filter catalog by category id instead of slug',
        (tester) async {
      await pumpCatalog(tester);
      await tester.pump();

      expect(find.text('Cuadernillo Amigo'), findsOneWidget);

      await tester.tap(find.text('Material'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Sin conexión con el servidor.'), findsNothing);
      expect(find.text('Insignia Guía'), findsOneWidget);
    });
  });
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}
