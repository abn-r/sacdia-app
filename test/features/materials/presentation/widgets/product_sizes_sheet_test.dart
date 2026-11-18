import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_category.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_item.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_program.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_variant.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_variant_option.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_variant_type.dart';
import 'package:sacdia_app/features/materials/presentation/providers/cart_provider.dart';
import 'package:sacdia_app/features/materials/presentation/widgets/product_sizes_sheet.dart';

import '../../support/materials_test_support.dart';

const _category = MaterialCategory(
  id: 'c1',
  slug: 'uniforme',
  label: 'Uniforme',
  sortOrder: 0,
);
const _program = MaterialProgram(id: 1, label: 'Conquistadores');

MaterialItem _shirt() => const MaterialItem(
      id: 'p1',
      sku: 'CAM',
      title: 'Camisa caqui',
      category: _category,
      programa: _program,
      priceCentavos: 28000,
      stock: 12,
      active: true,
      variant: MaterialVariant(
        id: 'v1',
        type: MaterialVariantType.talla,
        options: [
          MaterialVariantOption(id: 'ch', label: 'CH', stock: 6),
          MaterialVariantOption(id: 'm', label: 'M', stock: 4),
          MaterialVariantOption(id: 'g', label: 'G', stock: 2),
          MaterialVariantOption(id: 'xg', label: 'XG', stock: 0),
        ],
      ),
    );

MaterialItem _plain() => const MaterialItem(
      id: 'p2',
      sku: 'PAN',
      title: 'Pañoleta',
      category: _category,
      programa: _program,
      priceCentavos: 3000,
      stock: 10,
      active: true,
    );

void main() {
  setUpAll(initMaterialsL10n);

  Future<ProviderContainer> open(WidgetTester tester, MaterialItem item) async {
    await pumpMaterials(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showProductSheet(context, item),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first));
  }

  Finder plus(String id) => find.descendant(
        of: find.byKey(ValueKey('size-$id')),
        matching: find.bySemanticsLabel('Aumentar cantidad'),
      );

  testWidgets('lists every size with its stock and a live total',
      (tester) async {
    await open(tester, _shirt());

    expect(find.text('Tallas'.toUpperCase()), findsOneWidget);
    expect(find.text('Talla CH'), findsOneWidget);
    expect(find.text('Quedan 6'), findsOneWidget);
    expect(find.text('Quedan 2'), findsOneWidget);
    expect(find.text('Agotada'), findsOneWidget);
    // Sold out has no stepper.
    expect(plus('xg'), findsNothing);
    // Nothing chosen: the button is off.
    expect(find.text('Elige cuántas'), findsOneWidget);

    await tester.tap(plus('m'));
    await tester.pump();
    await tester.tap(plus('m'));
    await tester.pump();
    await tester.tap(plus('g'));
    await tester.pump();
    await tester.pump();

    expect(find.text(r'Agregar 3 · $840.00'), findsOneWidget);
  });

  testWidgets('low stock (3 or less) is announced in the warning color',
      (tester) async {
    await open(tester, _shirt());
    final low = tester.widget<Text>(find.text('Quedan 2'));
    final ok = tester.widget<Text>(find.text('Quedan 6'));
    expect(low.style!.color, isNot(ok.style!.color));
  });

  testWidgets('adds every size in one go and closes', (tester) async {
    final container = await open(tester, _shirt());
    final cart = container.listen(cartProvider, (_, __) {});
    addTearDown(cart.close);

    await tester.tap(plus('m'));
    await tester.pump();
    await tester.tap(plus('m'));
    await tester.pump();
    await tester.tap(plus('g'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('product-add')));
    await tester.pumpAndSettle();

    final lines = container.read(cartProvider).lines;
    expect(lines.map((l) => (l.variantOptionId, l.qty)),
        unorderedEquals([('m', 2), ('g', 1)]));
    expect(find.byType(ProductSizesSheet), findsNothing);
    expect(find.text('Se agregó Camisa caqui al carrito'), findsOneWidget);
  });

  testWidgets('a product without sizes shows one stepper', (tester) async {
    await open(tester, _plain());
    expect(find.byKey(const ValueKey('product-single')), findsOneWidget);
    await tester.tap(plus('single'));
    await tester.pump();
    await tester.tap(plus('single'));
    await tester.pump();
    await tester.pump();
    expect(find.text(r'Agregar 2 · $60.00'), findsOneWidget);
  });
}
