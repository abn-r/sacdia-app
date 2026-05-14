import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/material_entrega.dart';
import '../models/comprobante_model.dart';
import '../models/material_category_model.dart';
import '../models/material_config_model.dart';
import '../models/material_item_model.dart';
import '../models/material_programa_model.dart';
import '../models/orden_model.dart';

/// Interfaz para la fuente de datos remota del módulo de materiales.
abstract class MaterialesRemoteDataSource {
  // ── Catálogo ─────────────────────────────────────────────────────────────
  Future<List<MaterialItemModel>> browseCatalog({
    String? cat,
    int? programaId,
    String? q,
    int page = 1,
    int pageSize = 20,
  });

  Future<MaterialItemModel> getProductDetail(String id);
  Future<List<MaterialCategoryModel>> listCategorias();
  Future<List<MaterialProgramaModel>> listProgramas();

  // ── Órdenes ───────────────────────────────────────────────────────────────
  Future<OrdenModel> createOrder({
    required int clubSectionId,
    required List<({String productId, String? variantOptionId, int qty})> lines,
    required MaterialEntrega entrega,
    String? notas,
  });

  Future<List<OrdenModel>> listOrdenes({
    String? estado,
    int page = 1,
    int pageSize = 20,
  });

  Future<List<OrdenModel>> getOrderHistory({
    int page = 1,
    int pageSize = 20,
  });

  Future<OrdenModel> getOrderByFolio(String folioOrId);
  Future<OrdenModel> cancelOrder(String folioOrId, String reason);

  // ── Comprobantes ──────────────────────────────────────────────────────────
  Future<List<ComprobanteModel>> listComprobantes(String folioOrId);

  Future<ComprobanteModel> uploadComprobante({
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
/// Consume los endpoints bajo `/api/v1/materiales/*` del backend SACDIA.
/// Auth token es inyectado automáticamente por [AuthInterceptor].
class MaterialesRemoteDataSourceImpl implements MaterialesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'MaterialesDS';

  MaterialesRemoteDataSourceImpl({
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
        '$_baseUrl${ApiEndpoints.materiales}/catalogo',
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
        message: tr('materiales.errors.browse_catalog'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en browseCatalog', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<MaterialItemModel> getProductDetail(String id) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materiales}/catalogo/$id',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return MaterialItemModel.fromJson(json);
      }

      throw ServerException(
        message: tr('materiales.errors.get_product'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getProductDetail', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<MaterialCategoryModel>> listCategorias() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materiales}/catalogo/categorias',
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
        message: tr('materiales.errors.list_categorias'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en listCategorias', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<MaterialProgramaModel>> listProgramas() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materiales}/catalogo/programas',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final rawData = _extractData(body) as List<dynamic>;
        return rawData
            .map((item) =>
                MaterialProgramaModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('materiales.errors.list_programas'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en listProgramas', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Órdenes ───────────────────────────────────────────────────────────────

  @override
  Future<OrdenModel> createOrder({
    required int clubSectionId,
    required List<({String productId, String? variantOptionId, int qty})> lines,
    required MaterialEntrega entrega,
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
        'entrega': entrega.toApiString(),
        if (notas != null && notas.isNotEmpty) 'notas': notas,
      };

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.materiales}/ordenes',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.data as Map<String, dynamic>;
        final json = responseBody.containsKey('data')
            ? responseBody['data'] as Map<String, dynamic>
            : responseBody;
        return OrdenModel.fromJson(json);
      }

      throw ServerException(
        message: tr('materiales.errors.create_order'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en createOrder', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<OrdenModel>> listOrdenes({
    String? estado,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        if (estado != null) 'estado': estado,
      };

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materiales}/ordenes',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final rawData = _extractData(body) as List<dynamic>;
        return rawData
            .map((item) =>
                OrdenModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('materiales.errors.list_ordenes'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en listOrdenes', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<OrdenModel>> getOrderHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materiales}/ordenes/historial',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final rawData = _extractData(body) as List<dynamic>;
        return rawData
            .map((item) =>
                OrdenModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('materiales.errors.get_history'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getOrderHistory', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<OrdenModel> getOrderByFolio(String folioOrId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materiales}/ordenes/$folioOrId',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return OrdenModel.fromJson(json);
      }

      throw ServerException(
        message: tr('materiales.errors.get_orden'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getOrderByFolio', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<OrdenModel> cancelOrder(String folioOrId, String reason) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.materiales}/ordenes/$folioOrId/cancelar',
        data: {'cancel_reason': reason},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return OrdenModel.fromJson(json);
      }

      throw ServerException(
        message: tr('materiales.errors.cancel_order'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en cancelOrder', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Comprobantes ──────────────────────────────────────────────────────────

  @override
  Future<List<ComprobanteModel>> listComprobantes(String folioOrId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materiales}/comprobantes/$folioOrId',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final rawData = _extractData(body) as List<dynamic>;
        return rawData
            .map((item) =>
                ComprobanteModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('materiales.errors.list_comprobantes'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en listComprobantes', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<ComprobanteModel> uploadComprobante({
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
        '$_baseUrl${ApiEndpoints.materiales}/comprobantes/$folioOrId',
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
              'Comprobante upload: ${(fraction * 100).toStringAsFixed(1)}%',
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
        return ComprobanteModel.fromJson(json);
      }

      throw ServerException(
        message: tr('materiales.errors.upload_comprobante'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en uploadComprobante', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Configuración ─────────────────────────────────────────────────────────

  @override
  Future<MaterialConfigModel> getConfig() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.materiales}/configuracion',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return MaterialConfigModel.fromJson(json);
      }

      throw ServerException(
        message: tr('materiales.errors.get_config'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getConfig', tag: _tag, error: e);
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
  /// PDF y JPG son los más comunes para comprobantes.
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
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: ex);
    }
    return e.message ?? tr('common.error_network');
  }
}
