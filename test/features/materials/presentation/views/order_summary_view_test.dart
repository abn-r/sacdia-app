import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart' hide Order;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
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
import 'package:sacdia_app/features/materials/presentation/views/order_summary_view.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

class _FakeCreateOrder extends CreateOrderNotifier {
  _FakeCreateOrder(this.folio);

  final String? folio;

  @override
  Future<Either<Failure, Order>> confirm({
    required int clubSectionId,
    required List<({String productId, String? variantOptionId, int qty})> lines,
    required MaterialDelivery delivery,
    String? notas,
  }) async {
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
    slug: 'material',
    label: 'Material',
    sortOrder: 0,
  ),
  programa: MaterialProgram(id: 1, label: 'Aventureros'),
  priceCentavos: 7000,
  stock: 10,
  active: true,
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<GoRouter> pumpFlow(WidgetTester tester, {String? folio}) async {
    final container = ProviderContainer(
      overrides: [
        createOrderProvider.overrideWith(() => _FakeCreateOrder(folio)),
        clubContextProvider.overrideWith(
          (ref) async => const ClubContext(clubId: 1, sectionId: 5),
        ),
        configProvider.overrideWith(
          (ref) async => MaterialConfig(
            envioCentavosDefault: 0,
            deliveryOptions: const [MaterialDelivery.recoger],
            updatedAt: DateTime(2026, 1, 1),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(cartProvider, (_, __) {});
    container.read(cartProvider.notifier).addLine(_item);

    final router = GoRouter(
      initialLocation: '/catalog',
      routes: [
        GoRoute(
          path: '/catalog',
          builder: (_, __) => Scaffold(
            appBar: AppBar(title: const Text('CATALOG')),
          ),
        ),
        GoRoute(
          path: '/cart',
          builder: (_, __) => Scaffold(
            appBar: AppBar(title: const Text('CART')),
          ),
        ),
        GoRoute(
          path: '/summary',
          builder: (_, __) => const OrderSummaryView(),
        ),
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
          assetLoader: const _FileAssetLoader(),
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

    router.push('/cart');
    await tester.pumpAndSettle();
    router.push('/summary');
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
      'confirming an order shows the folio snackbar and returns to the catalog '
      'with a way back', (tester) async {
    final router = await pumpFlow(tester, folio: 'SOL20260003');

    await tester.tap(find.byType(SacButton));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('Pedido SOL20260003 enviado'), findsOneWidget);
    expect(find.text('CATALOG'), findsOneWidget);
    expect(find.text('Ver pedido'), findsOneWidget);
    // The stack was popped, not replaced: catalog is still the route above
    // the initial one only because it IS the initial one, so check the cart
    // and summary are gone.
    expect(find.text('CART'), findsNothing);
    expect(find.byType(OrderSummaryView), findsNothing);

    // "Ver pedido" opens the order detail on top of the catalog.
    await tester.tap(find.text('Ver pedido'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('ORDER order-1'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('falls back to a folio-less message when there is no folio yet',
      (tester) async {
    await pumpFlow(tester);

    await tester.tap(find.byType(SacButton));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('Pedido enviado'), findsOneWidget);
    expect(find.text('CATALOG'), findsOneWidget);
  });
}
