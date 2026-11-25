import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_offering.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_product.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_camporee_orders.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_camporee_orders_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_camporee_orders_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';

import '../../../../support/riverpod_test_support.dart';

CamporeeOrderProduct _product(String id) => CamporeeOrderProduct(
      productId: id,
      ownerScope: CamporeeOrderOwnerScope.union,
      title: 'Shirt $id',
      sizeScheme: CamporeeOrderSizeScheme.none,
      active: true,
    );

CamporeeOrderOffering _offering(
  String productId, {
  int price = 1000,
  int sort = 0,
  bool active = true,
}) =>
    CamporeeOrderOffering(
      offeringId: 'f-$productId',
      priceCentavos: price,
      active: active,
      sortOrder: sort,
      product: _product(productId),
    );

const _settings = CamporeeOrderSettings(ordersEnabled: true);
const _catalog = SupervisionSupplyCatalog(cutoffTime: '18:00', timezone: 'UTC');
const _slot =
    SupervisionSupplySlot(id: 's1', label: 'Lunch', deliverTime: '12:00');
const _supplyProduct = SupervisionSupplyProduct(
    id: 'p1', name: 'Rice', uom: SupervisionSupplyUom.kg, unitCostCentavos: 1);
const _failure = ServerFailure(
    message: 'locked', code: 422, errorCode: 'CAMPOREE_SUPPLIES_PRICE_LOCKED');

class _FakeRepo implements SupervisionCamporeeOrdersRepository {
  SupervisionCamporeeOrderConfig config = SupervisionCamporeeOrderConfig(
    settings: _settings,
    offerings: [
      _offering('a', price: 100, sort: 0),
      _offering('b', price: 200, sort: 3),
      _offering('c', price: 300, sort: 1, active: false),
      _offering('gone', price: 400, sort: 9),
    ],
    products: [_product('a'), _product('b'), _product('c'), _product('d')],
  );
  Failure? readFailure;
  Failure? writeFailure;

  int configReads = 0;
  int catalogReads = 0;
  final calls = <String>[];
  List<SupervisionOfferingInput>? replaced;
  Map<String, Object?>? args;

  Either<Failure, T> _w<T>(String name, T value, [Map<String, Object?>? a]) {
    calls.add(name);
    args = a;
    final f = writeFailure;
    return f == null ? Right(value) : Left(f);
  }

  @override
  Future<Either<Failure, SupervisionCamporeeOrderConfig>> getOrderConfig(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  }) async {
    configReads++;
    final f = readFailure;
    return f == null ? Right(config) : Left(f);
  }

  @override
  Future<Either<Failure, SupervisionSupplyCatalog>> getSupplyCatalog(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  }) async {
    catalogReads++;
    final f = readFailure;
    return f == null ? const Right(_catalog) : Left(f);
  }

  @override
  Future<Either<Failure, CamporeeOrderSettings>> updateOrderSettings(
    int camporeeId,
    SupervisionOrderSettingsPatch patch,
  ) async =>
      _w('settings', _settings);

  @override
  Future<Either<Failure, CamporeeOrderOfferingsCatalog>> replaceOfferings(
    int camporeeId,
    List<SupervisionOfferingInput> items,
  ) async {
    replaced = items;
    return _w(
        'replace', const CamporeeOrderOfferingsCatalog(settings: _settings));
  }

  @override
  Future<Either<Failure, SupervisionSupplyCatalog>> updateSupplyCutoff(
    int camporeeId,
    String hhmm,
  ) async =>
      _w('cutoff', _catalog, {'hhmm': hhmm});

  @override
  Future<Either<Failure, SupervisionSupplySlot>> createSupplySlot(
    int camporeeId, {
    required String label,
    required String deliverTime,
  }) async =>
      _w('createSlot', _slot, {'label': label, 'deliverTime': deliverTime});

  @override
  Future<Either<Failure, SupervisionSupplySlot>> updateSupplySlot(
    int camporeeId,
    String slotId, {
    String? label,
    String? deliverTime,
    bool? active,
  }) async =>
      _w('updateSlot', _slot, {'slotId': slotId, 'active': active});

  @override
  Future<Either<Failure, SupervisionSupplyProduct>> createSupplyProduct(
    int camporeeId, {
    required String name,
    required SupervisionSupplyUom uom,
    required int unitCostCentavos,
  }) async =>
      _w('createProduct', _supplyProduct, {'name': name});

  @override
  Future<Either<Failure, SupervisionSupplyProduct>> updateSupplyProduct(
    int camporeeId,
    String productId, {
    String? name,
    SupervisionSupplyUom? uom,
    int? unitCostCentavos,
    bool? active,
  }) async =>
      _w('updateProduct', _supplyProduct, {'productId': productId});
}

ProviderContainer _container(_FakeRepo repo) => createTestContainer(overrides: [
      supervisionCamporeeOrdersRepositoryProvider.overrideWithValue(repo),
    ]);

Map<String, ({int price, int sort})> _sent(_FakeRepo repo) => {
      for (final i in repo.replaced!)
        i.productId: (price: i.priceCentavos, sort: i.sortOrder),
    };

void main() {
  group('read providers', () {
    test('order config and supply catalog return the entities', () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      expect(await c.read(supervisionCamporeeOrderConfigProvider(7).future),
          repo.config);
      expect(
          await c.read(supervisionSupplyCatalogProvider(7).future), _catalog);
    });

    test('403 is a forbidden SupervisionLoadException', () async {
      final repo = _FakeRepo()
        ..readFailure = const AuthFailure(message: 'no', code: 403);
      final c = _container(repo);
      for (final future in [
        () => c.read(supervisionCamporeeOrderConfigProvider(7).future),
        () => c.read(supervisionSupplyCatalogProvider(7).future),
      ]) {
        Object? error;
        try {
          await future();
        } catch (e) {
          error = e;
        }
        expect(error, isA<SupervisionLoadException>());
        expect(isForbiddenFailure(error!), isTrue);
      }
    });

    test('other failures are not forbidden', () async {
      final repo = _FakeRepo()
        ..readFailure = const ServerFailure(message: 'boom', code: 500);
      final c = _container(repo);
      Object? error;
      try {
        await c.read(supervisionCamporeeOrderConfigProvider(7).future);
      } catch (e) {
        error = e;
      }
      expect(error, isA<SupervisionLoadException>());
      expect(isForbiddenFailure(error!), isFalse);
    });
  });

  group('setOffering', () {
    test('adding keeps active offerings in the library, next sortOrder',
        () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      final result = await c
          .read(supervisionCamporeeOrderActionsProvider)
          .setOffering(7, productId: 'd', offered: true, priceCentavos: 500);
      expect(result.ok, isTrue);
      // 'c' inactive and 'gone' (not in library) are not sent.
      expect(_sent(repo), {
        'a': (price: 100, sort: 0),
        'b': (price: 200, sort: 3),
        'd': (price: 500, sort: 10),
      });
    });

    test('adding to an empty config starts at sortOrder 0', () async {
      final repo = _FakeRepo()
        ..config = SupervisionCamporeeOrderConfig(
            settings: _settings, products: [_product('a')]);
      final c = _container(repo);
      await c
          .read(supervisionCamporeeOrderActionsProvider)
          .setOffering(7, productId: 'a', offered: true, priceCentavos: 50);
      expect(_sent(repo), {'a': (price: 50, sort: 0)});
    });

    test('updating keeps its sortOrder and changes the price', () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      await c
          .read(supervisionCamporeeOrderActionsProvider)
          .setOffering(7, productId: 'b', offered: true, priceCentavos: 999);
      expect(_sent(repo), {
        'a': (price: 100, sort: 0),
        'b': (price: 999, sort: 3),
      });
    });

    test('re-offering an inactive offering appends it', () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      await c
          .read(supervisionCamporeeOrderActionsProvider)
          .setOffering(7, productId: 'c', offered: true, priceCentavos: 321);
      expect(_sent(repo)['c'], (price: 321, sort: 10));
    });

    test('removing omits it', () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      await c
          .read(supervisionCamporeeOrderActionsProvider)
          .setOffering(7, productId: 'a', offered: false);
      expect(_sent(repo), {'b': (price: 200, sort: 3)});
    });

    test('invalid price short-circuits without touching the server', () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      final actions = c.read(supervisionCamporeeOrderActionsProvider);
      for (final price in [null, 0, -5]) {
        final r = await actions.setOffering(7,
            productId: 'd', offered: true, priceCentavos: price);
        expect(r.ok, isFalse);
        expect(r.errorCode, 'CAMPOREE_ORDER_OFFERING_INVALID');
      }
      expect(repo.configReads, 0);
      expect(repo.calls, isEmpty);
    });

    test('a failing config read fails the action', () async {
      final repo = _FakeRepo()
        ..readFailure = const AuthFailure(message: 'no', code: 403);
      final c = _container(repo);
      final r = await c
          .read(supervisionCamporeeOrderActionsProvider)
          .setOffering(7, productId: 'a', offered: false);
      expect(r.ok, isFalse);
      expect(r.isForbidden, isTrue);
      expect(repo.calls, isEmpty);
    });

    test('server failure keeps the code and does not invalidate', () async {
      final repo = _FakeRepo()
        ..writeFailure = const ServerFailure(
            message: 'x',
            code: 422,
            errorCode: 'CAMPOREE_ORDER_OPTION_REQUIRED');
      final c = _container(repo);
      final sub =
          c.listen(supervisionCamporeeOrderConfigProvider(7), (_, __) {});
      addTearDown(sub.close);
      await c.read(supervisionCamporeeOrderConfigProvider(7).future);
      final r = await c
          .read(supervisionCamporeeOrderActionsProvider)
          .setOffering(7, productId: 'd', offered: true, priceCentavos: 5);
      await Future<void>.delayed(Duration.zero);
      expect(r.errorCode, 'CAMPOREE_ORDER_OPTION_REQUIRED');
      expect(repo.configReads, 1);
    });
  });

  group('invalidation', () {
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('order actions re-read the config on success', () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      final sub =
          c.listen(supervisionCamporeeOrderConfigProvider(7), (_, __) {});
      addTearDown(sub.close);
      await c.read(supervisionCamporeeOrderConfigProvider(7).future);
      final actions = c.read(supervisionCamporeeOrderActionsProvider);

      expect(
          (await actions.updateOrderSettings(
                  7, const SupervisionOrderSettingsPatch(ordersEnabled: false)))
              .ok,
          isTrue);
      await c.read(supervisionCamporeeOrderConfigProvider(7).future);
      expect(repo.configReads, 2);

      expect((await actions.setOffering(7, productId: 'a', offered: false)).ok,
          isTrue);
      await c.read(supervisionCamporeeOrderConfigProvider(7).future);
      await settle();
      expect(repo.configReads, 3);
    });

    test('order settings failure does not invalidate', () async {
      final repo = _FakeRepo()..writeFailure = _failure;
      final c = _container(repo);
      final sub =
          c.listen(supervisionCamporeeOrderConfigProvider(7), (_, __) {});
      addTearDown(sub.close);
      await c.read(supervisionCamporeeOrderConfigProvider(7).future);
      final r = await c
          .read(supervisionCamporeeOrderActionsProvider)
          .updateOrderSettings(
              7, const SupervisionOrderSettingsPatch(ordersEnabled: true));
      expect(r.ok, isFalse);
      expect(r.errorCode, 'CAMPOREE_SUPPLIES_PRICE_LOCKED');
      await settle();
      expect(repo.configReads, 1);
    });

    test('each supply action re-reads the catalog on success', () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      final sub = c.listen(supervisionSupplyCatalogProvider(7), (_, __) {});
      addTearDown(sub.close);
      await c.read(supervisionSupplyCatalogProvider(7).future);
      final actions = c.read(supervisionCamporeeOrderActionsProvider);
      var expected = 1;

      Future<void> check(Future<dynamic> Function() act) async {
        expect((await act()).ok, isTrue);
        await c.read(supervisionSupplyCatalogProvider(7).future);
        expected++;
        expect(repo.catalogReads, expected);
      }

      await check(() => actions.updateSupplyCutoff(7, '10:00'));
      await check(
          () => actions.saveSupplySlot(7, label: 'a', deliverTime: '08:00'));
      await check(() => actions.saveSupplySlot(7, slotId: 's1', active: false));
      await check(() => actions.saveSupplyProduct(7,
          name: 'n', uom: SupervisionSupplyUom.l, unitCostCentavos: 1));
      await check(
          () => actions.saveSupplyProduct(7, productId: 'p1', active: false));
      expect(repo.calls, [
        'cutoff',
        'createSlot',
        'updateSlot',
        'createProduct',
        'updateProduct',
      ]);
      // The order config is untouched.
      expect(repo.configReads, 0);
    });

    test('supply failures do not invalidate', () async {
      final repo = _FakeRepo()..writeFailure = _failure;
      final c = _container(repo);
      final sub = c.listen(supervisionSupplyCatalogProvider(7), (_, __) {});
      addTearDown(sub.close);
      await c.read(supervisionSupplyCatalogProvider(7).future);
      final actions = c.read(supervisionCamporeeOrderActionsProvider);
      final results = [
        await actions.updateSupplyCutoff(7, '10:00'),
        await actions.saveSupplySlot(7, slotId: 's1', label: 'x'),
        await actions.saveSupplyProduct(7,
            productId: 'p1', unitCostCentavos: 3),
      ];
      await settle();
      expect(results.every((r) => !r.ok), isTrue);
      expect(results.first.errorMessage, 'locked');
      expect(repo.catalogReads, 1);
    });

    test('create without required fields fails without calling the server',
        () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      final actions = c.read(supervisionCamporeeOrderActionsProvider);
      final results = [
        await actions.saveSupplySlot(7, label: 'a'),
        await actions.saveSupplySlot(7, deliverTime: '08:00'),
        await actions.saveSupplyProduct(7,
            name: 'n', uom: SupervisionSupplyUom.kg),
        await actions.saveSupplyProduct(7, name: 'n', unitCostCentavos: 1),
        await actions.saveSupplyProduct(7,
            uom: SupervisionSupplyUom.kg, unitCostCentavos: 1),
      ];
      expect(results.every((r) => !r.ok), isTrue);
      expect(repo.calls, isEmpty);
    });
  });

  group('without listeners', () {
    test('actions do not throw when no provider is being watched', () async {
      final repo = _FakeRepo();
      final c = _container(repo);
      final actions = c.read(supervisionCamporeeOrderActionsProvider);
      expect(
          (await actions.updateOrderSettings(
                  7, const SupervisionOrderSettingsPatch(ordersEnabled: true)))
              .ok,
          isTrue);
      expect(
          (await actions.setOffering(7,
                  productId: 'd', offered: true, priceCentavos: 10))
              .ok,
          isTrue);
      expect((await actions.updateSupplyCutoff(7, '10:00')).ok, isTrue);
      expect(
          (await actions.saveSupplySlot(7, label: 'a', deliverTime: '08:00'))
              .ok,
          isTrue);
      expect(
          (await actions.saveSupplyProduct(7, productId: 'p1', active: true))
              .ok,
          isTrue);
    });
  });
}
