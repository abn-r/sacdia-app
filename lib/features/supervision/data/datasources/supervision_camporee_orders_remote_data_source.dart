import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/authorization_stale.dart';
import '../../../../core/errors/business_error.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../camporee_orders/domain/entities/camporee_order_offering.dart';
import '../../domain/entities/supervision_camporee_orders.dart';
import '../models/supervision_camporee_orders_model.dart';

abstract class SupervisionCamporeeOrdersRemoteDataSource {
  /// GET /union-camporees/:id/order-offerings + GET
  /// /camporee-order-products?active=true, in parallel.
  Future<SupervisionCamporeeOrderConfig> getOrderConfig(
    int camporeeId, {
    CancelToken? cancelToken,
  });

  /// PATCH /union-camporees/:id/orders-settings
  Future<CamporeeOrderSettings> updateOrderSettings(
    int camporeeId,
    SupervisionOrderSettingsPatch patch,
  );

  /// PUT /union-camporees/:id/order-offerings (full replacement)
  Future<CamporeeOrderOfferingsCatalog> replaceOfferings(
    int camporeeId,
    List<SupervisionOfferingInput> items,
  );

  /// GET /union-camporees/:id/supply-catalog
  Future<SupervisionSupplyCatalog> getSupplyCatalog(
    int camporeeId, {
    CancelToken? cancelToken,
  });

  /// PATCH /union-camporees/:id/supply-settings
  Future<SupervisionSupplyCatalog> updateSupplyCutoff(
    int camporeeId,
    String hhmm,
  );

  /// POST /union-camporees/:id/supply-slots
  Future<SupervisionSupplySlot> createSupplySlot(
    int camporeeId, {
    required String label,
    required String deliverTime,
  });

  /// PATCH /union-camporees/:id/supply-slots/:slotId
  Future<SupervisionSupplySlot> updateSupplySlot(
    int camporeeId,
    String slotId, {
    String? label,
    String? deliverTime,
    bool? active,
  });

  /// POST /union-camporees/:id/supply-products
  Future<SupervisionSupplyProduct> createSupplyProduct(
    int camporeeId, {
    required String name,
    required SupervisionSupplyUom uom,
    required int unitCostCentavos,
  });

  /// PATCH /union-camporees/:id/supply-products/:productId
  Future<SupervisionSupplyProduct> updateSupplyProduct(
    int camporeeId,
    String productId, {
    String? name,
    SupervisionSupplyUom? uom,
    int? unitCostCentavos,
    bool? active,
  });
}

class SupervisionCamporeeOrdersRemoteDataSourceImpl
    implements SupervisionCamporeeOrdersRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'SupervisionCamporeeOrdersDS';

  SupervisionCamporeeOrdersRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  String _camporee(int camporeeId) =>
      '$_baseUrl${ApiEndpoints.unionCamporees}/$camporeeId';

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
      if (isAuthorizationStale(e)) throw authorizationStaleException(e);
      // Only `code` and `message` are read; never `details`.
      throw businessErrorFrom(e, fallbackMessage: tr('common.error_network'));
    }
    if (e is AppException) throw e;
    throw ServerException(message: e.toString());
  }

  bool _isOk(int? code) => code == 200 || code == 201;

  Object? _unwrap(Object? raw) =>
      raw is Map && raw.containsKey('data') ? raw['data'] : raw;

  Never _badResponse(Response<dynamic> response) => throw ServerException(
        message: tr('common.error_network'),
        code: response.statusCode,
      );

  /// Unwrapped body of a 2xx response.
  Object? _body(Response<dynamic> response) {
    if (!_isOk(response.statusCode)) _badResponse(response);
    return _unwrap(response.data);
  }

  String _wireUom(SupervisionSupplyUom uom) {
    final wire = SupervisionCamporeeOrdersModel.uomToWire(uom);
    if (wire == null) {
      throw ServerException(message: 'Invalid unit of measure');
    }
    return wire;
  }

  String _iso(DateTime value) => value.toUtc().toIso8601String();

  @override
  Future<SupervisionCamporeeOrderConfig> getOrderConfig(
    int camporeeId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final responses = await Future.wait([
        _dio.get(
          '${_camporee(camporeeId)}/order-offerings',
          cancelToken: cancelToken,
        ),
        _dio.get(
          '$_baseUrl${ApiEndpoints.camporeeOrderProducts}',
          queryParameters: {'active': true},
          cancelToken: cancelToken,
        ),
      ]);
      final offerings = _body(responses[0]);
      if (offerings is! Map) _badResponse(responses[0]);
      final catalog =
          SupervisionCamporeeOrdersModel.parseOfferingsCatalog(offerings);
      return SupervisionCamporeeOrderConfig(
        settings: catalog.settings,
        offerings: catalog.items,
        products:
            SupervisionCamporeeOrdersModel.parseProducts(_body(responses[1])),
      );
    } catch (e) {
      AppLogger.e('Error en getOrderConfig (supervision camporee orders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<CamporeeOrderSettings> updateOrderSettings(
    int camporeeId,
    SupervisionOrderSettingsPatch patch,
  ) async {
    try {
      final body = <String, Object?>{
        if (patch.ordersEnabled != null) 'orders_enabled': patch.ordersEnabled,
        if (patch.clearOpensAt)
          'orders_opens_at': null
        else if (patch.opensAt != null)
          'orders_opens_at': _iso(patch.opensAt!),
        if (patch.clearDeadline)
          'orders_deadline': null
        else if (patch.deadline != null)
          'orders_deadline': _iso(patch.deadline!),
      };
      final response = await _dio.patch(
        '${_camporee(camporeeId)}/orders-settings',
        data: body,
      );
      final data = _body(response);
      if (data is! Map) _badResponse(response);
      return SupervisionCamporeeOrdersModel.parseSettings(data);
    } catch (e) {
      AppLogger.e('Error en updateOrderSettings (supervision camporee orders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<CamporeeOrderOfferingsCatalog> replaceOfferings(
    int camporeeId,
    List<SupervisionOfferingInput> items,
  ) async {
    try {
      final response = await _dio.put(
        '${_camporee(camporeeId)}/order-offerings',
        data: {
          'items': [
            for (final item in items)
              {
                'product_id': item.productId,
                'price_centavos': item.priceCentavos,
                'active': true,
                'sort_order': item.sortOrder,
              },
          ],
        },
      );
      final data = _body(response);
      if (data is! Map) _badResponse(response);
      return SupervisionCamporeeOrdersModel.parseOfferingsCatalog(data);
    } catch (e) {
      AppLogger.e('Error en replaceOfferings (supervision camporee orders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionSupplyCatalog> getSupplyCatalog(
    int camporeeId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '${_camporee(camporeeId)}/supply-catalog',
        cancelToken: cancelToken,
      );
      return _catalog(response);
    } catch (e) {
      AppLogger.e('Error en getSupplyCatalog (supervision camporee orders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  SupervisionSupplyCatalog _catalog(Response<dynamic> response) {
    final catalog =
        SupervisionCamporeeOrdersModel.tryParseCatalog(_body(response));
    if (catalog == null) _badResponse(response);
    return catalog;
  }

  @override
  Future<SupervisionSupplyCatalog> updateSupplyCutoff(
    int camporeeId,
    String hhmm,
  ) async {
    try {
      final response = await _dio.patch(
        '${_camporee(camporeeId)}/supply-settings',
        data: {'supply_edit_cutoff_local_time': hhmm},
      );
      return _catalog(response);
    } catch (e) {
      AppLogger.e('Error en updateSupplyCutoff (supervision camporee orders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  SupervisionSupplySlot _slot(Response<dynamic> response) {
    final slot = SupervisionCamporeeOrdersModel.tryParseSlot(_body(response));
    if (slot == null) _badResponse(response);
    return slot;
  }

  SupervisionSupplyProduct _product(Response<dynamic> response) {
    final product =
        SupervisionCamporeeOrdersModel.tryParseProduct(_body(response));
    if (product == null) _badResponse(response);
    return product;
  }

  @override
  Future<SupervisionSupplySlot> createSupplySlot(
    int camporeeId, {
    required String label,
    required String deliverTime,
  }) async {
    try {
      final response = await _dio.post(
        '${_camporee(camporeeId)}/supply-slots',
        data: {'label': label, 'deliver_time': deliverTime},
      );
      return _slot(response);
    } catch (e) {
      AppLogger.e('Error en createSupplySlot (supervision camporee orders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionSupplySlot> updateSupplySlot(
    int camporeeId,
    String slotId, {
    String? label,
    String? deliverTime,
    bool? active,
  }) async {
    try {
      final response = await _dio.patch(
        '${_camporee(camporeeId)}/supply-slots/$slotId',
        data: {
          if (label != null) 'label': label,
          if (deliverTime != null) 'deliver_time': deliverTime,
          if (active != null) 'active': active,
        },
      );
      return _slot(response);
    } catch (e) {
      AppLogger.e('Error en updateSupplySlot (supervision camporee orders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionSupplyProduct> createSupplyProduct(
    int camporeeId, {
    required String name,
    required SupervisionSupplyUom uom,
    required int unitCostCentavos,
  }) async {
    try {
      final wireUom = _wireUom(uom);
      final response = await _dio.post(
        '${_camporee(camporeeId)}/supply-products',
        data: {
          'name': name,
          'uom': wireUom,
          'unit_cost_centavos': unitCostCentavos,
        },
      );
      return _product(response);
    } catch (e) {
      AppLogger.e('Error en createSupplyProduct (supervision camporee orders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionSupplyProduct> updateSupplyProduct(
    int camporeeId,
    String productId, {
    String? name,
    SupervisionSupplyUom? uom,
    int? unitCostCentavos,
    bool? active,
  }) async {
    try {
      final wireUom = uom == null ? null : _wireUom(uom);
      final response = await _dio.patch(
        '${_camporee(camporeeId)}/supply-products/$productId',
        data: {
          if (name != null) 'name': name,
          if (wireUom != null) 'uom': wireUom,
          if (unitCostCentavos != null) 'unit_cost_centavos': unitCostCentavos,
          if (active != null) 'active': active,
        },
      );
      return _product(response);
    } catch (e) {
      AppLogger.e('Error en updateSupplyProduct (supervision camporee orders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
