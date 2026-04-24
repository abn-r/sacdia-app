import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/inventory_item.dart';
import '../models/inventory_category_model.dart';
import '../models/inventory_item_model.dart';

abstract class InventoryRemoteDataSource {
  Future<List<InventoryItemModel>> getItems({
    required int clubId,
    required String instanceType,
    CancelToken? cancelToken,
  });

  Future<InventoryItemModel> getItem({
    required int itemId,
    CancelToken? cancelToken,
  });

  Future<InventoryItemModel> createItem({
    required int clubId,
    required String name,
    required int categoryId,
    required int quantity,
    required ItemCondition condition,
    String? description,
    String? serialNumber,
    DateTime? purchaseDate,
    double? estimatedValue,
    String? location,
    String? assignedTo,
    String? notes,
  });

  Future<InventoryItemModel> updateItem({
    required int itemId,
    String? name,
    int? categoryId,
    int? quantity,
    ItemCondition? condition,
    String? description,
    String? serialNumber,
    DateTime? purchaseDate,
    double? estimatedValue,
    String? location,
    String? assignedTo,
    String? notes,
  });

  Future<void> deleteItem({required int itemId});

  Future<List<InventoryCategoryModel>> getCategories({
    CancelToken? cancelToken,
  });
}

class InventoryRemoteDataSourceImpl implements InventoryRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'InventoryDS';

  InventoryRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  // ── GET /inventory/catalogs/inventory-categories ──────────────────────────

  @override
  Future<List<InventoryCategoryModel>> getCategories({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.inventory}/catalogs/inventory-categories',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        final List<dynamic> rawList = body is List
            ? body
            : (body as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
        return rawList
            .map((e) =>
                InventoryCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('inventory.errors.get_categories'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getCategories', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /inventory/clubs/:clubId/inventory ────────────────────────────────

  @override
  Future<List<InventoryItemModel>> getItems({
    required int clubId,
    required String instanceType,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.inventory}/clubs/$clubId/inventory',
        queryParameters: {'instanceType': instanceType},
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        final List<dynamic> rawList = body is List
            ? body
            : (body as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
        return rawList
            .map((e) =>
                InventoryItemModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('inventory.errors.get_items'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getItems', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /inventory/inventory/:id ──────────────────────────────────────────

  @override
  Future<InventoryItemModel> getItem({
    required int itemId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.inventory}/inventory/$itemId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json =
            body.containsKey('data') ? body['data'] as Map<String, dynamic> : body;
        return InventoryItemModel.fromJson(json);
      }

      throw ServerException(
        message: tr('inventory.errors.get_item'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getItem', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /inventory/clubs/:clubId/inventory ───────────────────────────────

  @override
  Future<InventoryItemModel> createItem({
    required int clubId,
    required String name,
    required int categoryId,
    required int quantity,
    required ItemCondition condition,
    String? description,
    String? serialNumber,
    DateTime? purchaseDate,
    double? estimatedValue,
    String? location,
    String? assignedTo,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'inventory_category_id': categoryId,
        'quantity': quantity,
        'condition': InventoryItemModel.conditionToString(condition),
        if (description != null && description.isNotEmpty)
          'description': description,
        if (serialNumber != null && serialNumber.isNotEmpty)
          'serial_number': serialNumber,
        if (purchaseDate != null)
          'purchase_date':
              '${purchaseDate.year}-${purchaseDate.month.toString().padLeft(2, '0')}-${purchaseDate.day.toString().padLeft(2, '0')}',
        if (estimatedValue != null) 'estimated_value': estimatedValue,
        if (location != null && location.isNotEmpty) 'location': location,
        if (assignedTo != null && assignedTo.isNotEmpty)
          'assigned_to': assignedTo,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.inventory}/clubs/$clubId/inventory',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resp = response.data as Map<String, dynamic>;
        final json =
            resp.containsKey('data') ? resp['data'] as Map<String, dynamic> : resp;
        return InventoryItemModel.fromJson(json);
      }

      throw ServerException(
        message: tr('inventory.errors.create_item'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en createItem', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── PATCH /inventory/inventory/:id ────────────────────────────────────────

  @override
  Future<InventoryItemModel> updateItem({
    required int itemId,
    String? name,
    int? categoryId,
    int? quantity,
    ItemCondition? condition,
    String? description,
    String? serialNumber,
    DateTime? purchaseDate,
    double? estimatedValue,
    String? location,
    String? assignedTo,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        if (name != null) 'name': name,
        if (categoryId != null) 'inventory_category_id': categoryId,
        if (quantity != null) 'quantity': quantity,
        if (condition != null)
          'condition': InventoryItemModel.conditionToString(condition),
        if (description != null) 'description': description,
        if (serialNumber != null) 'serial_number': serialNumber,
        if (purchaseDate != null)
          'purchase_date':
              '${purchaseDate.year}-${purchaseDate.month.toString().padLeft(2, '0')}-${purchaseDate.day.toString().padLeft(2, '0')}',
        if (estimatedValue != null) 'estimated_value': estimatedValue,
        if (location != null) 'location': location,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (notes != null) 'notes': notes,
      };

      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.inventory}/inventory/$itemId',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resp = response.data as Map<String, dynamic>;
        final json =
            resp.containsKey('data') ? resp['data'] as Map<String, dynamic> : resp;
        return InventoryItemModel.fromJson(json);
      }

      throw ServerException(
        message: tr('inventory.errors.update_item'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en updateItem', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── DELETE /inventory/inventory/:id ───────────────────────────────────────

  @override
  Future<void> deleteItem({required int itemId}) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.inventory}/inventory/$itemId',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
        message: tr('inventory.errors.delete_item'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en deleteItem', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Error helper ──────────────────────────────────────────────────────────

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
      final msg = _extractDioMessage(e);
      throw ServerException(message: msg, code: e.response?.statusCode);
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return (data['message'] ?? e.message ?? tr('common.error_network')).toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? tr('common.error_network');
  }
}
