import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/inventory/domain/entities/inventory_category.dart';
import 'package:sacdia_app/features/inventory/domain/entities/inventory_item.dart';
import 'package:sacdia_app/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:sacdia_app/features/inventory/presentation/views/inventory_item_detail_view.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../support/riverpod_test_support.dart';

/// Minimal Spanish strings so the bottom bar renders its real labels.
class _EsLabels extends AssetLoader {
  const _EsLabels();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => {
        'common': {'edit': 'Editar', 'delete': 'Eliminar'},
      };
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('bottom bar labels are not ellipsized at 402pt', (tester) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final item = InventoryItem(
      id: 1,
      name: 'Tienda de campaña',
      category: const InventoryCategory(id: 1, name: 'Equipo'),
      quantity: 2,
      condition: ItemCondition.bueno,
      registeredByName: 'Ana',
      registeredAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          canManageInventoryProvider.overrideWith((ref) async => true),
          inventoryItemDetailProvider(1).overrideWith((ref) async => item),
          clubContextProvider.overrideWith((ref) async => null),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          assetLoader: const _EsLabels(),
          fallbackLocale: const Locale('es'),
          startLocale: const Locale('es'),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: InventoryItemDetailView(item: item),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The test font (Ahem) is far wider than the real one, so this is a
    // conservative check: if it fits here it fits on device.
    final finder = find.text('Editar');
    expect(finder, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(finder);
    expect(paragraph.didExceedMaxLines, isFalse);
  });
}
