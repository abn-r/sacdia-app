/// Harness for `SupervisionCamporeeOrdersView`: a fake
/// [SupervisionCamporeeOrdersRepository] that records every call and whose
/// answers can be swapped between calls, a small fake of the union camporee
/// repository (top bar subtitle), entity builders and a pump.
///
/// Reuses the user, auth fake and localization setup of
/// `supervision_view_test_harness.dart` (read only).
library;

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_offering.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_product.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_camporee_orders.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_union_camporee.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_camporee_orders_repository.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_union_camporees_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_camporee_orders_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_union_camporees_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_camporee_orders_view.dart';

import 'supervision_view_test_harness.dart';

const kSuppliesCap = 'camporee_supplies.configure';

const ServerFailure kOrdersBoom = ServerFailure(message: 'boom');
const AuthFailure kOrdersForbidden = AuthFailure(message: 'nope', code: 403);

ServerFailure codedFailure(String code, [String message = 'server says no']) =>
    ServerFailure(message: message, errorCode: code);

// ── Builders ────────────────────────────────────────────────────────────────

CamporeeOrderProductOption sizeOption(String id, {bool active = true}) =>
    CamporeeOrderProductOption(
      optionId: id,
      label: 'Talla $id',
      sortOrder: 0,
      active: active,
    );

CamporeeOrderProduct orderProduct(
  String id, {
  String? title,
  String? description,
  CamporeeOrderSizeScheme scheme = CamporeeOrderSizeScheme.none,
  List<CamporeeOrderProductOption> options = const [],
}) =>
    CamporeeOrderProduct(
      productId: id,
      ownerScope: CamporeeOrderOwnerScope.union,
      title: title ?? 'Producto $id',
      description: description,
      sizeScheme: scheme,
      active: true,
      options: options,
    );

CamporeeOrderOffering orderOffering(
  CamporeeOrderProduct product, {
  int priceCentavos = 12050,
  bool active = true,
  int sortOrder = 0,
}) =>
    CamporeeOrderOffering(
      offeringId: 'o-${product.productId}',
      priceCentavos: priceCentavos,
      active: active,
      sortOrder: sortOrder,
      product: product,
    );

SupervisionCamporeeOrderConfig orderConfig({
  bool ordersEnabled = false,
  DateTime? opensAt,
  DateTime? deadline,
  List<CamporeeOrderOffering> offerings = const [],
  List<CamporeeOrderProduct> products = const [],
}) =>
    SupervisionCamporeeOrderConfig(
      settings: CamporeeOrderSettings(
        ordersEnabled: ordersEnabled,
        ordersOpensAt: opensAt,
        ordersDeadline: deadline,
      ),
      offerings: offerings,
      products: products,
    );

SupervisionSupplySlot supplySlot(
  String id, {
  String? label,
  String time = '12:00',
  bool active = true,
}) =>
    SupervisionSupplySlot(
      id: id,
      label: label ?? 'Horario $id',
      deliverTime: time,
      active: active,
    );

SupervisionSupplyProduct supplyProduct(
  String id, {
  String? name,
  SupervisionSupplyUom uom = SupervisionSupplyUom.kg,
  int centavos = 2500,
  bool active = true,
}) =>
    SupervisionSupplyProduct(
      id: id,
      name: name ?? 'Insumo $id',
      uom: uom,
      unitCostCentavos: centavos,
      active: active,
    );

SupervisionSupplyCatalog supplyCatalog({
  String cutoff = '18:30',
  String timezone = 'America/Mexico_City',
  List<SupervisionSupplySlot> slots = const [],
  List<SupervisionSupplyProduct> products = const [],
}) =>
    SupervisionSupplyCatalog(
      cutoffTime: cutoff,
      timezone: timezone,
      slots: slots,
      products: products,
    );

// ── Recorded calls ──────────────────────────────────────────────────────────

class SlotCall {
  const SlotCall({
    required this.slotId,
    required this.label,
    required this.deliverTime,
    required this.active,
  });

  final String? slotId;
  final String? label;
  final String? deliverTime;
  final bool? active;
}

class SupplyProductCall {
  const SupplyProductCall({
    required this.productId,
    required this.name,
    required this.uom,
    required this.unitCostCentavos,
    required this.active,
  });

  final String? productId;
  final String? name;
  final SupervisionSupplyUom? uom;
  final int? unitCostCentavos;
  final bool? active;
}

// ── Fakes ───────────────────────────────────────────────────────────────────

/// Answers come from the mutable `on...` callbacks; every call is recorded.
class FakeOrdersRepo implements SupervisionCamporeeOrdersRepository {
  FakeOrdersRepo({SupervisionCamporeeOrderConfig? config}) {
    this.config = config ?? orderConfig();
  }

  late SupervisionCamporeeOrderConfig config;
  SupervisionSupplyCatalog catalog = supplyCatalog();

  Future<Either<Failure, SupervisionCamporeeOrderConfig>> Function(int id)?
      onOrderConfig;
  Future<Either<Failure, SupervisionSupplyCatalog>> Function(int id)?
      onSupplyCatalog;
  Future<Either<Failure, CamporeeOrderSettings>> Function(
    SupervisionOrderSettingsPatch patch,
  )? onUpdateSettings;
  Future<Either<Failure, CamporeeOrderOfferingsCatalog>> Function(
    List<SupervisionOfferingInput> items,
  )? onReplace;
  Future<Either<Failure, SupervisionSupplyCatalog>> Function(String hhmm)?
      onCutoff;
  Future<Either<Failure, SupervisionSupplySlot>> Function(SlotCall call)?
      onSlot;
  Future<Either<Failure, SupervisionSupplyProduct>> Function(
    SupplyProductCall call,
  )? onSupplyProduct;

  final orderConfigCalls = <int>[];
  final supplyCatalogCalls = <int>[];
  final settingsCalls = <SupervisionOrderSettingsPatch>[];
  final replaceCalls = <List<SupervisionOfferingInput>>[];
  final cutoffCalls = <String>[];
  final createSlotCalls = <SlotCall>[];
  final updateSlotCalls = <SlotCall>[];
  final createProductCalls = <SupplyProductCall>[];
  final updateProductCalls = <SupplyProductCall>[];

  @override
  Future<Either<Failure, SupervisionCamporeeOrderConfig>> getOrderConfig(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  }) async {
    orderConfigCalls.add(camporeeId);
    final handler = onOrderConfig;
    return handler != null ? handler(camporeeId) : Right(config);
  }

  @override
  Future<Either<Failure, SupervisionSupplyCatalog>> getSupplyCatalog(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  }) async {
    supplyCatalogCalls.add(camporeeId);
    final handler = onSupplyCatalog;
    return handler != null ? handler(camporeeId) : Right(catalog);
  }

  @override
  Future<Either<Failure, CamporeeOrderSettings>> updateOrderSettings(
    int camporeeId,
    SupervisionOrderSettingsPatch patch,
  ) async {
    settingsCalls.add(patch);
    final handler = onUpdateSettings;
    return handler != null ? handler(patch) : Right(config.settings);
  }

  @override
  Future<Either<Failure, CamporeeOrderOfferingsCatalog>> replaceOfferings(
    int camporeeId,
    List<SupervisionOfferingInput> items,
  ) async {
    replaceCalls.add(items);
    final handler = onReplace;
    return handler != null
        ? handler(items)
        : Right(CamporeeOrderOfferingsCatalog(settings: config.settings));
  }

  @override
  Future<Either<Failure, SupervisionSupplyCatalog>> updateSupplyCutoff(
    int camporeeId,
    String hhmm,
  ) async {
    cutoffCalls.add(hhmm);
    final handler = onCutoff;
    return handler != null ? handler(hhmm) : Right(catalog);
  }

  @override
  Future<Either<Failure, SupervisionSupplySlot>> createSupplySlot(
    int camporeeId, {
    required String label,
    required String deliverTime,
  }) async {
    final call = SlotCall(
      slotId: null,
      label: label,
      deliverTime: deliverTime,
      active: null,
    );
    createSlotCalls.add(call);
    final handler = onSlot;
    return handler != null
        ? handler(call)
        : Right(supplySlot('new', label: label, time: deliverTime));
  }

  @override
  Future<Either<Failure, SupervisionSupplySlot>> updateSupplySlot(
    int camporeeId,
    String slotId, {
    String? label,
    String? deliverTime,
    bool? active,
  }) async {
    final call = SlotCall(
      slotId: slotId,
      label: label,
      deliverTime: deliverTime,
      active: active,
    );
    updateSlotCalls.add(call);
    final handler = onSlot;
    return handler != null ? handler(call) : Right(supplySlot(slotId));
  }

  @override
  Future<Either<Failure, SupervisionSupplyProduct>> createSupplyProduct(
    int camporeeId, {
    required String name,
    required SupervisionSupplyUom uom,
    required int unitCostCentavos,
  }) async {
    final call = SupplyProductCall(
      productId: null,
      name: name,
      uom: uom,
      unitCostCentavos: unitCostCentavos,
      active: null,
    );
    createProductCalls.add(call);
    final handler = onSupplyProduct;
    return handler != null ? handler(call) : Right(supplyProduct('new'));
  }

  @override
  Future<Either<Failure, SupervisionSupplyProduct>> updateSupplyProduct(
    int camporeeId,
    String productId, {
    String? name,
    SupervisionSupplyUom? uom,
    int? unitCostCentavos,
    bool? active,
  }) async {
    final call = SupplyProductCall(
      productId: productId,
      name: name,
      uom: uom,
      unitCostCentavos: unitCostCentavos,
      active: active,
    );
    updateProductCalls.add(call);
    final handler = onSupplyProduct;
    return handler != null ? handler(call) : Right(supplyProduct(productId));
  }
}

/// Only `getCamporee` is used by the view (top bar subtitle).
class FakeCamporeeNameRepo implements SupervisionUnionCamporeesRepository {
  FakeCamporeeNameRepo({this.name = 'Camporee Unión 2026'});

  final String name;

  @override
  Future<Either<Failure, SupervisionUnionCamporee>> getCamporee(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  }) async =>
      Right(SupervisionUnionCamporee(id: camporeeId, name: name));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

// ── Pump ────────────────────────────────────────────────────────────────────

/// Pumps the view as a supervisor with [capabilities] (supplies by default).
Future<FakeOrdersRepo> pumpOrdersView(
  WidgetTester tester, {
  FakeOrdersRepo? repo,
  String camporeeId = '7',
  List<String> capabilities = const [kSupervisionAppView, kSuppliesCap],
  String camporeeName = 'Camporee Unión 2026',
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  final fake = repo ?? FakeOrdersRepo();
  await pumpSupervisionView(
    tester,
    home: SupervisionCamporeeOrdersView(camporeeId: camporeeId),
    user: supervisionUser(capabilities: capabilities),
    overrides: [
      supervisionCamporeeOrdersRepositoryProvider.overrideWithValue(fake),
      supervisionUnionCamporeesRepositoryProvider
          .overrideWithValue(FakeCamporeeNameRepo(name: camporeeName)),
    ],
    size: size,
    textScale: textScale,
    settle: settle,
  );
  return fake;
}
