import 'package:dartz/dartz.dart' hide Order;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_category.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_config.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_delivery.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_item.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_program.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_status.dart';
import 'package:sacdia_app/features/materials/domain/entities/order.dart';
import 'package:sacdia_app/features/materials/presentation/providers/cart_provider.dart';
import 'package:sacdia_app/features/materials/presentation/providers/config_provider.dart';
import 'package:sacdia_app/features/materials/presentation/providers/create_order_provider.dart';
import 'package:sacdia_app/features/materials/presentation/views/cart_view.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

import '../../../../support/riverpod_test_support.dart';
import '../../support/materials_test_support.dart';

class _FakeCreateOrder extends CreateOrderNotifier {
  _FakeCreateOrder(this.folio, this.calls);

  final String? folio;
  final List<MaterialDelivery> calls;

  @override
  Future<Either<Failure, Order>> confirm({
    required int clubSectionId,
    required List<({String productId, String? variantOptionId, int qty})> lines,
    required MaterialDelivery delivery,
    String? notas,
  }) async {
    calls.add(delivery);
    return Right(
      Order(
        id: 'order-1',
        folioReferencia: folio,
        status: MaterialStatus.enRevision,
        clubSectionId: clubSectionId,
        createdBy: 'user-1',
        subtotalCentavos: 7000,
        envioCentavos: 0,
        totalCentavos: 7000,
        delivery: delivery,
        createdAt: DateTime(2026, 1, 1),
        lines: const [],
        receipts: const [],
      ),
    );
  }
}

const _item = MaterialItem(
  id: 'p1',
  sku: 'SKU-1',
  title: 'Pañoleta',
  category: MaterialCategory(
    id: 'cat-1',
    slug: 'panoletas',
    label: 'Pañoletas',
    sortOrder: 0,
  ),
  programa: MaterialProgram(id: 1, label: 'Aventureros'),
  priceCentavos: 7000,
  stock: 10,
  active: true,
);

void main() {
  setUpAll(initMaterialsL10n);

  Future<(GoRouter, ProviderContainer, List<MaterialDelivery>)> pumpFlow(
    WidgetTester tester, {
    String? folio,
    List<MaterialDelivery> options = const [
      MaterialDelivery.recoger,
      MaterialDelivery.envio,
    ],
  }) async {
    final calls = <MaterialDelivery>[];
    final container = createTestContainer(
      overrides: [
        createOrderProvider.overrideWith(() => _FakeCreateOrder(folio, calls)),
        clubContextProvider.overrideWith(
          (ref) async => const ClubContext(clubId: 1, sectionId: 5),
        ),
        configProvider.overrideWith(
          (ref) async => MaterialConfig(
            envioCentavosDefault: 8000,
            deliveryOptions: options,
            updatedAt: DateTime(2026, 1, 1),
          ),
        ),
      ],
    );
    container.listen(cartProvider, (_, __) {});
    container.read(cartProvider.notifier).addLine(_item);

    final router = GoRouter(
      initialLocation: '/home/materials',
      routes: [
        GoRoute(
          path: '/home/materials',
          builder: (_, __) =>
              Scaffold(appBar: AppBar(title: const Text('LIST'))),
        ),
        GoRoute(
          path: '/catalog',
          builder: (_, __) =>
              Scaffold(appBar: AppBar(title: const Text('CATALOG'))),
        ),
        GoRoute(path: '/cart', builder: (_, __) => const CartView()),
        GoRoute(
          path: '/home/materials/order/:folio',
          builder: (_, state) => Scaffold(
            appBar:
                AppBar(title: Text('ORDER ${state.pathParameters['folio']}')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          assetLoader: const FileAssetLoader(),
          fallbackLocale: const Locale('es'),
          startLocale: const Locale('es'),
          child: Builder(
            builder: (context) => MaterialApp.router(
              theme: AppTheme.lightTheme,
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/catalog');
    await tester.pumpAndSettle();
    router.push('/cart');
    await tester.pumpAndSettle();
    return (router, container, calls);
  }

  testWidgets('one screen: products, delivery cards, notes, totals, confirm',
      (tester) async {
    await pumpFlow(tester);

    expect(find.text('Tu pedido'), findsOneWidget);
    expect(find.text('Pañoleta'), findsOneWidget);
    expect(find.text(r'$70.00'), findsWidgets);
    expect(find.byKey(const ValueKey('delivery-recoger')), findsOneWidget);
    expect(find.byKey(const ValueKey('delivery-envio')), findsOneWidget);
    expect(find.byType(DropdownButton), findsNothing);
    expect(find.text('Notas (opcional)'), findsOneWidget);
    expect(find.text(r'Confirmar pedido · $70.00'), findsOneWidget);
  });

  testWidgets('choosing shipping adds its cost to the total and the button',
      (tester) async {
    final (_, _, calls) = await pumpFlow(tester);

    await tester.tap(find.byKey(const ValueKey('delivery-envio')));
    await tester.pumpAndSettle();
    expect(find.text(r'Confirmar pedido · $150.00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cart-confirm')));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(calls, [MaterialDelivery.envio]);
  });

  testWidgets(
      'confirming shows the folio snackbar and returns to the list with a '
      'way to the order', (tester) async {
    final (router, _, _) = await pumpFlow(tester, folio: 'SOL20260003');

    await tester.tap(find.byKey(const ValueKey('cart-confirm')));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('Pedido SOL20260003 enviado'), findsOneWidget);
    expect(find.text('LIST'), findsOneWidget);
    expect(find.text('CATALOG'), findsNothing);
    expect(find.byType(CartView), findsNothing);

    await tester.tap(find.text('Ver pedido'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('ORDER SOL20260003'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('falls back to a folio-less message when there is no folio yet',
      (tester) async {
    await pumpFlow(tester);
    await tester.tap(find.byKey(const ValueKey('cart-confirm')));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('Pedido enviado'), findsOneWidget);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('removing the last unit offers to undo', (tester) async {
    final (_, container, _) = await pumpFlow(tester);

    await tester.tap(find.bySemanticsLabel('Disminuir cantidad'));
    await tester.pumpAndSettle();
    expect(container.read(cartProvider).lines, isEmpty);
    expect(find.text('Quitaste Pañoleta'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(container.read(cartProvider).lines, hasLength(1));
  });
}
