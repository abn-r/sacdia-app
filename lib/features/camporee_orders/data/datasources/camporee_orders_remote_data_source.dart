import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../payment_orders/data/models/payment_obligation_model.dart';
import '../models/camporee_order_model.dart';
import '../models/camporee_order_offering_model.dart';
import '../models/camporee_order_product_model.dart';

/// Fuente remota de pedidos de mercancía. No reutiliza payment-orders
/// de inscripción (`POST /camporees/:id/payment-orders`).
abstract class CamporeeOrdersRemoteDataSource {
  Future<List<CamporeeOrderModel>> listOrders({
    int? localCamporeeId,
    int? unionCamporeeId,
    String? status,
    CancelToken? cancelToken,
  });

  Future<CamporeeOrderModel> getOrder(
    String orderId, {
    CancelToken? cancelToken,
  });

  Future<CamporeeOrderModel> createOrder({
    required int camporeeId,
    required String camporeeType,
    required List<Map<String, dynamic>> lines,
    String? idempotencyKey,
  });

  Future<CamporeeOrderOfferingsResultModel> getOfferings({
    required int camporeeId,
    required String camporeeType,
    CancelToken? cancelToken,
  });

  Future<List<CamporeeOrderProductModel>> listProducts({
    bool? active,
    CancelToken? cancelToken,
  });

  Future<String> downloadOrderPdf(String orderId, {CancelToken? cancelToken});

  Future<CamporeeOrderModel> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  });

  Future<CamporeeOrderProofModel> getProof(String orderId);

  Future<CamporeeOrderModel> cancelOrder(String orderId);

  Future<CamporeeOrderModel> deliverLineToMember({
    required String orderId,
    required String lineId,
  });

  Future<List<PaymentObligationModel>> listPendingObligations({
    int? camporeeId,
    int? unionCamporeeId,
    CancelToken? cancelToken,
  });
}

/// Implementación Dio de pedidos de camporee.
class CamporeeOrdersRemoteDataSourceImpl
    implements CamporeeOrdersRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'CamporeeOrdersDS';

  CamporeeOrdersRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  String _camporeeBasePath(String camporeeType) => camporeeType == 'union'
      ? ApiEndpoints.unionCamporees
      : ApiEndpoints.camporees;

  @override
  Future<List<CamporeeOrderModel>> listOrders({
    int? localCamporeeId,
    int? unionCamporeeId,
    String? status,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (status != null) 'status': status,
        if (localCamporeeId != null) 'camporee_id': localCamporeeId,
        if (unionCamporeeId != null) 'union_camporee_id': unionCamporeeId,
      };
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporeeOrders}',
        queryParameters: queryParams.isEmpty ? null : queryParams,
        cancelToken: cancelToken,
      );
      return _unwrapList(response.data)
          .map((e) => CamporeeOrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error en listOrders', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<CamporeeOrderModel> getOrder(
    String orderId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporeeOrders}/$orderId',
        cancelToken: cancelToken,
      );
      return CamporeeOrderModel.fromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en getOrder', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<CamporeeOrderModel> createOrder({
    required int camporeeId,
    required String camporeeType,
    required List<Map<String, dynamic>> lines,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${_camporeeBasePath(camporeeType)}/$camporeeId/orders',
        data: {'lines': lines},
        options: Options(
          headers: {
            if (idempotencyKey != null && idempotencyKey.isNotEmpty)
              'Idempotency-Key': idempotencyKey,
          },
        ),
      );
      return CamporeeOrderModel.fromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en createOrder', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<CamporeeOrderOfferingsResultModel> getOfferings({
    required int camporeeId,
    required String camporeeType,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${_camporeeBasePath(camporeeType)}/$camporeeId/order-offerings',
        cancelToken: cancelToken,
      );
      return CamporeeOrderOfferingsResultModel.fromJson(
        _unwrapMap(response.data),
      );
    } catch (e) {
      AppLogger.e('Error en getOfferings', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<CamporeeOrderProductModel>> listProducts({
    bool? active,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporeeOrderProducts}',
        queryParameters: active == null ? null : {'active': active},
        cancelToken: cancelToken,
      );
      return _unwrapList(response.data)
          .map((e) =>
              CamporeeOrderProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error en listProducts', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<String> downloadOrderPdf(
    String orderId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/sacdia_camporee_order_${orderId}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await _dio.download(
        '$_baseUrl${ApiEndpoints.camporeeOrders}/$orderId/document',
        filePath,
        cancelToken: cancelToken,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final file = File(filePath);
      if (!await file.exists() || await file.length() == 0) {
        throw ServerException(
          message: tr('camporee_orders.errors.download_document'),
        );
      }
      return filePath;
    } catch (e) {
      AppLogger.e('Error en downloadOrderPdf', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<CamporeeOrderModel> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.camporeeOrders}/$orderId/proof',
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return CamporeeOrderModel.fromJson(_unwrapOrderPayload(response.data));
    } catch (e) {
      AppLogger.e('Error en uploadProof', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<CamporeeOrderProofModel> getProof(String orderId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.camporeeOrders}/$orderId/proof',
      );
      return CamporeeOrderProofModel.fromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en getProof', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<CamporeeOrderModel> cancelOrder(String orderId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.camporeeOrders}/$orderId/cancel',
      );
      return CamporeeOrderModel.fromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en cancelOrder', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<CamporeeOrderModel> deliverLineToMember({
    required String orderId,
    required String lineId,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.camporeeOrders}/$orderId/lines/$lineId/deliver-to-member',
      );
      return CamporeeOrderModel.fromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en deliverLineToMember', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<PaymentObligationModel>> listPendingObligations({
    int? camporeeId,
    int? unionCamporeeId,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (camporeeId != null) 'camporee_id': camporeeId,
        if (unionCamporeeId != null) 'union_camporee_id': unionCamporeeId,
      };
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.paymentObligations}/pending',
        queryParameters: queryParams.isEmpty ? null : queryParams,
        cancelToken: cancelToken,
      );
      return _unwrapList(response.data)
          .map(
            (e) => PaymentObligationModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      AppLogger.e('Error en listPendingObligations', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Map<String, dynamic> _unwrapMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body;
    }
    return <String, dynamic>{};
  }

  /// Upload proof responde `{ proof, order }`; el resto de mutaciones
  /// devuelven el CamporeeOrderView directo.
  Map<String, dynamic> _unwrapOrderPayload(dynamic body) {
    final data = _unwrapMap(body);
    final order = data['order'];
    if (order is Map<String, dynamic>) return order;
    return data;
  }

  List<dynamic> _unwrapList(dynamic body) {
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) return data;
    }
    return const [];
  }

  static const Map<String, String> _businessErrorKeys = {
    'CAMPOREE_ORDERS_DISABLED': 'camporee_orders.errors.disabled',
    'CAMPOREE_ORDERS_NOT_OPEN': 'camporee_orders.errors.not_open',
    'CAMPOREE_ORDERS_CLOSED': 'camporee_orders.errors.closed',
    'CAMPOREE_ORDER_NOT_FOUND': 'camporee_orders.errors.not_found',
    'CAMPOREE_ORDER_FORBIDDEN': 'camporee_orders.errors.forbidden',
    'CAMPOREE_ORDER_INVALID_TRANSITION':
        'camporee_orders.errors.invalid_transition',
    'CAMPOREE_ORDER_LINES_REQUIRED': 'camporee_orders.errors.lines_required',
    'CAMPOREE_ORDER_MEMBER_NOT_ELIGIBLE':
        'camporee_orders.errors.member_not_eligible',
    'CAMPOREE_ORDER_OFFERING_INVALID':
        'camporee_orders.errors.offering_invalid',
    'CAMPOREE_ORDER_OPTION_REQUIRED': 'camporee_orders.errors.option_required',
    'CAMPOREE_ORDER_OPTION_FORBIDDEN':
        'camporee_orders.errors.option_forbidden',
    'CAMPOREE_ORDER_PRODUCT_SCOPE_INVALID':
        'camporee_orders.errors.product_scope_invalid',
    'CAMPOREE_ORDER_PAYMENT_CONFIG_REQUIRED':
        'camporee_orders.errors.payment_config_required',
    'CAMPOREE_ORDER_MAKER_CHECKER': 'camporee_orders.errors.maker_checker',
    'CAMPOREE_ORDER_PROOF_INVALID_FILE':
        'camporee_orders.errors.proof_invalid_file',
    'CAMPOREE_ORDER_PROOF_NOT_FOUND':
        'camporee_orders.errors.proof_not_found',
    'CAMPOREE_ORDER_REJECT_REASON_REQUIRED':
        'camporee_orders.errors.reject_reason_required',
    'CAMPOREE_ORDER_AUTHORIZATION_REASON_REQUIRED':
        'camporee_orders.errors.authorization_reason_required',
    'CAMPOREE_ORDER_NOT_DELIVERED_TO_SECTION':
        'camporee_orders.errors.not_delivered_to_section',
    'CAMPOREE_ORDER_LINE_NOT_FOUND': 'camporee_orders.errors.line_not_found',
    'CAMPOREE_ORDER_DISTRIBUTION_FORBIDDEN':
        'camporee_orders.errors.distribution_forbidden',
  };

  String? _extractDioCode(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) return data['code']?.toString();
    } catch (_) {
      // Cuerpo no parseable — se cae al mensaje genérico.
    }
    return null;
  }

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
      final businessCode = _extractDioCode(e);
      final i18nKey =
          businessCode != null ? _businessErrorKeys[businessCode] : null;
      if (i18nKey != null) {
        throw ServerException(
          message: tr(i18nKey),
          code: e.response?.statusCode,
        );
      }
      throw ServerException(
        message: _extractDioMessage(e),
        code: e.response?.statusCode,
      );
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return (data['message'] ?? e.message ?? tr('common.error_network'))
            .toString();
      }
    } catch (_) {
      // Ignorado: mensaje genérico abajo.
    }
    return e.message ?? tr('common.error_network');
  }
}
