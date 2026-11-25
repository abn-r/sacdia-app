import 'package:dartz/dartz.dart' show Either;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/providers/keep_alive_during.dart';
import '../../../auth/presentation/providers/auth_providers.dart'
    show apiBaseUrlProvider;
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/supervision_camporee_orders_remote_data_source.dart';
import '../../data/repositories/supervision_camporee_orders_repository_impl.dart';
import '../../domain/entities/supervision_camporee_orders.dart';
import '../../domain/repositories/supervision_camporee_orders_repository.dart';
import 'supervision_action_result.dart';
import 'supervision_providers.dart';
import 'supervision_union_camporees_providers.dart'
    show supervisionUnionCamporeeProvider, supervisionUnionCamporeesProvider;

final supervisionCamporeeOrdersRemoteDataSourceProvider =
    Provider<SupervisionCamporeeOrdersRemoteDataSource>((ref) {
  return SupervisionCamporeeOrdersRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final supervisionCamporeeOrdersRepositoryProvider =
    Provider<SupervisionCamporeeOrdersRepository>((ref) {
  return SupervisionCamporeeOrdersRepositoryImpl(
    remoteDataSource:
        ref.read(supervisionCamporeeOrdersRemoteDataSourceProvider),
  );
});

/// Order window, offerings and the offerable library of a union camporee.
final supervisionCamporeeOrderConfigProvider = FutureProvider.autoDispose
    .family<SupervisionCamporeeOrderConfig, int>((ref, camporeeId) async {
  final repository = ref.read(supervisionCamporeeOrdersRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result =
      await repository.getOrderConfig(camporeeId, cancelToken: cancelToken);
  return result.fold(
    (failure) => throw SupervisionLoadException.fromFailure(failure),
    (config) => config,
  );
});

/// Supply cutoff, delivery slots and products of a union camporee.
final supervisionSupplyCatalogProvider = FutureProvider.autoDispose
    .family<SupervisionSupplyCatalog, int>((ref, camporeeId) async {
  final repository = ref.read(supervisionCamporeeOrdersRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result =
      await repository.getSupplyCatalog(camporeeId, cancelToken: cancelToken);
  return result.fold(
    (failure) => throw SupervisionLoadException.fromFailure(failure),
    (catalog) => catalog,
  );
});

/// Stateless: safe to `ref.read` from a view.
class SupervisionCamporeeOrderActions {
  const SupervisionCamporeeOrderActions(this._ref);

  final Ref _ref;

  Future<SupervisionActionResult> updateOrderSettings(
    int camporeeId,
    SupervisionOrderSettingsPatch patch,
  ) =>
      _run(
        () {
          _ref.invalidate(supervisionCamporeeOrderConfigProvider(camporeeId));
          // The camporee list and detail may show the order window.
          _ref.invalidate(supervisionUnionCamporeesProvider);
          _ref.invalidate(supervisionUnionCamporeeProvider(camporeeId));
        },
        (repo) => repo.updateOrderSettings(camporeeId, patch),
      );

  /// Offers [productId] at [priceCentavos] (or stops offering it when
  /// [offered] is false) by sending the FULL replacement: every currently
  /// ACTIVE offering whose product is in the active library, with this one
  /// added, updated or removed. A new offering gets the next sortOrder (max
  /// over every offering the server returned, plus one); an existing one
  /// keeps its sortOrder.
  Future<SupervisionActionResult> setOffering(
    int camporeeId, {
    required String productId,
    required bool offered,
    int? priceCentavos,
  }) async {
    if (offered && (priceCentavos == null || priceCentavos < 1)) {
      return const SupervisionActionResult.failure(
        errorCode: 'CAMPOREE_ORDER_OFFERING_INVALID',
      );
    }
    return _ref.keepAliveDuring(() async {
      final provider = supervisionCamporeeOrderConfigProvider(camporeeId);
      // The read provider is autoDispose: hold it while the config is read.
      final subscription =
          _ref.listen(provider, (_, __) {}, onError: (_, __) {});
      final SupervisionCamporeeOrderConfig config;
      try {
        config = await _ref.read(provider.future);
      } on SupervisionLoadException catch (e) {
        return SupervisionActionResult.failure(
          errorMessage: e.message,
          isForbidden: e.isForbidden,
        );
      } catch (_) {
        return const SupervisionActionResult.failure();
      } finally {
        subscription.close();
      }

      final libraryIds = config.products.map((p) => p.productId).toSet();
      final inputs = <SupervisionOfferingInput>[
        for (final o in config.offerings)
          if (o.active && libraryIds.contains(o.product.productId))
            SupervisionOfferingInput(
              productId: o.product.productId,
              priceCentavos: o.priceCentavos,
              sortOrder: o.sortOrder,
            ),
      ];
      final index = inputs.indexWhere((i) => i.productId == productId);
      if (!offered) {
        if (index >= 0) inputs.removeAt(index);
      } else if (index >= 0) {
        inputs[index] = SupervisionOfferingInput(
          productId: productId,
          priceCentavos: priceCentavos!,
          sortOrder: inputs[index].sortOrder,
        );
      } else {
        final maxSort = config.offerings.isEmpty
            ? -1
            : config.offerings
                .map((o) => o.sortOrder)
                .reduce((a, b) => a > b ? a : b);
        inputs.add(SupervisionOfferingInput(
          productId: productId,
          priceCentavos: priceCentavos!,
          sortOrder: maxSort + 1,
        ));
      }
      return _finish(
        await _ref
            .read(supervisionCamporeeOrdersRepositoryProvider)
            .replaceOfferings(camporeeId, inputs),
        () =>
            _ref.invalidate(supervisionCamporeeOrderConfigProvider(camporeeId)),
      );
    });
  }

  Future<SupervisionActionResult> updateSupplyCutoff(
    int camporeeId,
    String hhmm,
  ) =>
      _run(
        () => _ref.invalidate(supervisionSupplyCatalogProvider(camporeeId)),
        (repo) => repo.updateSupplyCutoff(camporeeId, hhmm),
      );

  /// [slotId] null creates the slot (label and deliverTime required).
  Future<SupervisionActionResult> saveSupplySlot(
    int camporeeId, {
    String? slotId,
    String? label,
    String? deliverTime,
    bool? active,
  }) {
    if (slotId == null && (label == null || deliverTime == null)) {
      return Future.value(const SupervisionActionResult.failure());
    }
    return _run(
      () => _ref.invalidate(supervisionSupplyCatalogProvider(camporeeId)),
      (repo) => slotId == null
          ? repo.createSupplySlot(
              camporeeId,
              label: label!,
              deliverTime: deliverTime!,
            )
          : repo.updateSupplySlot(
              camporeeId,
              slotId,
              label: label,
              deliverTime: deliverTime,
              active: active,
            ),
    );
  }

  /// [productId] null creates the product (name, uom and unitCostCentavos
  /// required).
  Future<SupervisionActionResult> saveSupplyProduct(
    int camporeeId, {
    String? productId,
    String? name,
    SupervisionSupplyUom? uom,
    int? unitCostCentavos,
    bool? active,
  }) {
    if (productId == null &&
        (name == null || uom == null || unitCostCentavos == null)) {
      return Future.value(const SupervisionActionResult.failure());
    }
    return _run(
      () => _ref.invalidate(supervisionSupplyCatalogProvider(camporeeId)),
      (repo) => productId == null
          ? repo.createSupplyProduct(
              camporeeId,
              name: name!,
              uom: uom!,
              unitCostCentavos: unitCostCentavos!,
            )
          : repo.updateSupplyProduct(
              camporeeId,
              productId,
              name: name,
              uom: uom,
              unitCostCentavos: unitCostCentavos,
              active: active,
            ),
    );
  }

  SupervisionActionResult _finish(
    Either<Failure, Object?> result,
    void Function() invalidateChanged,
  ) =>
      result.fold(
        SupervisionActionResult.fromFailure,
        (_) {
          invalidateChanged();
          return const SupervisionActionResult.success();
        },
      );

  Future<SupervisionActionResult> _run(
    void Function() invalidateChanged,
    Future<Either<Failure, Object?>> Function(
            SupervisionCamporeeOrdersRepository repo)
        call,
  ) =>
      _ref.keepAliveDuring(() async {
        final repository =
            _ref.read(supervisionCamporeeOrdersRepositoryProvider);
        return _finish(await call(repository), invalidateChanged);
      });
}

final supervisionCamporeeOrderActionsProvider =
    Provider<SupervisionCamporeeOrderActions>(
  (ref) => SupervisionCamporeeOrderActions(ref),
);
