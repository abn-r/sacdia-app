import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/material_delivery.dart';
import '../models/receipt_model.dart';
import '../models/material_category_model.dart';
import '../models/material_config_model.dart';
import '../models/material_item_model.dart';
import '../models/material_program_model.dart';
import '../models/order_model.dart';

/// Interfaz para la fuente de datos remota del módulo de materiales.
abstract class MaterialsRemoteDataSource {
  // ── Catálogo ─────────────────────────────────────────────────────────────
  Future<List<MaterialItemModel>> browseCatalog({
    String? cat,
    int? programaId,
    String? q,
    int page = 1,
    int pageSize = 20,
  });

  Future<MaterialItemModel> getProductDetail(String id);
  Future<List<MaterialCategoryModel>> listCategories();
  Future<List<MaterialProgramModel>> listPrograms();

  // ── Órdenes ───────────────────────────────────────────────────────────────
  Future<OrderModel> createOrder({
    required int clubSectionId,
    required List<({String productId, String? variantOptionId, int qty})> lines,
    required MaterialDelivery delivery,
    String? notas,
  });

  Future<List<OrderModel>> listOrders({
    String? status,
    int page = 1,
    int pageSize = 20,
  });

  Future<List<OrderModel>> getOrderHistory({
    int page = 1,
    int pageSize = 20,
  });

  Future<OrderModel> getOrderByFolio(String folioOrId);
  Future<OrderModel> cancelOrder(String folioOrId, String reason);

  // ── Receipts ──────────────────────────────────────────────────────────────
  Future<List<ReceiptModel>> listReceipts(String folioOrId);

  Future<ReceiptModel> uploadReceipt({
    required String folioOrId,
    required File file,
    required int montoCentavos,
    required String refBancariaDeclarada,
    required DateTime fechaPago,
    void Function(double)? onProgress,
  });

  // ── Configuración ─────────────────────────────────────────────────────────
  Future<MaterialConfigModel> getConfig();
}

/// Implementación de la fuente de datos remota del módulo de materiales.
///
/// Consume los endpoints bajo `/api/v1/materials/*` del backend SACDIA.
/// Auth token es inyectado automáticamente por [AuthInterceptor].
class MaterialsRemoteDataSourceImpl implements MaterialsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'MaterialsDS';

  MaterialsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  // ── Catálogo ──────────────────────────────────────────────────────────────

  @override
  Future<List<MaterialItemModel>> browseCatalog({
    String? cat,
    int? programaId,
    String? q,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        if (cat != null) 'cat': cat,
        if (programaId != null) 'programa': programaId,
        if (q != null && q.isNotEmpty) 'q': q,
      };

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materials}/catalog',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final rawData = _extractData(body) as List<dynamic>;
        return rawData
            .map((item) =>
                MaterialItemModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('materials.errors.browse_catalog'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error in browseCatalog', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<MaterialItemModel> getProductDetail(String id) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materials}/catalog/$id',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return MaterialItemModel.fromJson(json);
      }

      throw ServerException(
        message: tr('materials.errors.get_product'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error in getProductDetail', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<MaterialCategoryModel>> listCategories() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materials}/catalog/categories',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final rawData = _extractData(body) as List<dynamic>;
        return rawData
            .map((item) =>
                MaterialCategoryModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('materials.errors.list_categorias'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error in listCategories', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<MaterialProgramModel>> listPrograms() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materials}/catalog/programs',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final rawData = _extractData(body) as List<dynamic>;
        return rawData
            .map((item) =>
                MaterialProgramModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('materials.errors.list_programas'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error in listPrograms', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Órdenes ───────────────────────────────────────────────────────────────

  @override
  Future<OrderModel> createOrder({
    required int clubSectionId,
    required List<({String productId, String? variantOptionId, int qty})> lines,
    required MaterialDelivery delivery,
    String? notas,
  }) async {
    try {
      final body = <String, dynamic>{
        'club_section_id': clubSectionId,
        'lines': lines
            .map((l) => {
                  'product_id': l.productId,
                  if (l.variantOptionId != null)
                    'variant_option_id': l.variantOptionId,
                  'qty': l.qty,
                })
            .toList(),
        'entrega': delivery.toApiString(),
        if (notas != null && notas.isNotEmpty) 'notas': notas,
      };

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.materials}/orders',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.data as Map<String, dynamic>;
        final json = responseBody.containsKey('data')
            ? responseBody['data'] as Map<String, dynamic>
            : responseBody;
        return OrderModel.fromJson(json);
      }

      throw ServerException(
        message: tr('materials.errors.create_order'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error in createOrder', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<OrderModel>> listOrders({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        if (status != null) 'estado': status,
      };

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materials}/orders',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final rawData = _extractData(body) as List<dynamic>;
        return rawData
            .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('materials.errors.list_ordenes'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error in listOrders', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<OrderModel>> getOrderHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materials}/orders/history',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final rawData = _extractData(body) as List<dynamic>;
        return rawData
            .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('materials.errors.get_history'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error in getOrderHistory', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<OrderModel> getOrderByFolio(String folioOrId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materials}/orders/$folioOrId',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return OrderModel.fromJson(json);
      }

      throw ServerException(
        message: tr('materials.errors.get_orden'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error in getOrderByFolio', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<OrderModel> cancelOrder(String folioOrId, String reason) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.materials}/orders//cancel',
        data: {'cancel_reason': reason},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return OrderModel.fromJson(json);
      }

      throw ServerException(
        message: tr('materials.errors.cancel_order'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error in cancelOrder', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Receipts ──────────────────────────────────────────────────────────────

  @override
  Future<List<ReceiptModel>> listReceipts(String folioOrId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materials}/receipts/$folioOrId',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final rawData = _extractData(body) as List<dynamic>;
        return rawData
            .map((item) =>
                ReceiptModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('materials.errors.list_comprobantes'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error in listReceipts', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<ReceiptModel> uploadReceipt({
    required String folioOrId,
    required File file,
    required int montoCentavos,
    required String refBancariaDeclarada,
    required DateTime fechaPago,
    void Function(double)? onProgress,
  }) async {
    try {
      // Derive MIME from extension — NEVER trust the original filename for
      // content type. The backend also validates MIME server-side.
      final ext = file.path.split('.').last.toLowerCase();
      final mime = _mimeFromExt(ext);

      final formFields = <String, dynamic>{
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
          contentType: DioMediaType.parse(mime),
        ),
        'monto_centavos': montoCentavos.toString(),
        'ref_bancaria_declarada': refBancariaDeclarada,
        // Backend expects ISO date string (date only, e.g. "2026-05-13")
        'fecha_pago': fechaPago.toIso8601String().split('T').first,
      };

      final formData = FormData.fromMap(formFields);

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.materials}/receipts/$folioOrId',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final fraction = sent / total;
            onProgress?.call(fraction);
            AppLogger.d(
              'Receipt upload: ${(fraction * 100).toStringAsFixed(1)}%',
              tag: _tag,
            );
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return ReceiptModel.fromJson(json);
      }

      throw ServerException(
        message: tr('materials.errors.upload_comprobante'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error in uploadReceipt', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Configuración ─────────────────────────────────────────────────────────

  @override
  Future<MaterialConfigModel> getConfig() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materials}/config',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return MaterialConfigModel.fromJson(json);
      }

      throw ServerException(
        message: tr('materials.errors.get_config'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error in getConfig', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Extrae el array/objeto de datos del envelope `{ data: [...] }` o devuelve
  /// el body completo si no hay envelope.
  dynamic _extractData(Map<String, dynamic> body) {
    if (body.containsKey('data') && body['data'] != null) {
      return body['data'];
    }
    return body;
  }

  /// Mapea extensión de archivo a MIME type.
  String _mimeFromExt(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  /// Convierte excepciones a tipos conocidos.
  ///
  /// Respeta el patrón establecido en [EvidenceFolderRemoteDataSourceImpl].
  Never _rethrow(Object e) {
    if (e is DioException) {
      final statusCode = e.response?.statusCode;
      final msg = _extractDioMessage(e);
      if (statusCode == 404) {
        throw NotFoundException(message: msg, code: statusCode);
      }
      throw ServerException(message: msg, code: statusCode);
    }
    if (e is ServerException || e is AuthException || e is NotFoundException) {
      throw e;
    }
    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return (data['message'] ?? e.message ?? tr('common.error_network'))
            .toString();
      }
    } catch (ex) {
      AppLogger.w('Error parsing error response', tag: _tag, error: ex);
    }
    return e.message ?? tr('common.error_network');
  }
}
