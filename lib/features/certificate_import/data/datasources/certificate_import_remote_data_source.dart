import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/certificate_import_batch_model.dart';
import '../models/certificate_import_item_model.dart';
import '../../domain/entities/certificate_import_payloads.dart';

abstract class CertificateImportRemoteDataSource {
  Future<CertificateImportBatchModel> createBatch({
    required List<CertificateImportFilePayload> files,
  });

  Future<CertificateImportBatchModel> processOcr(String batchId);

  Future<CertificateImportBatchModel> getBatch(String batchId);

  Future<CertificateImportItemModel> updateItem({
    required String batchId,
    required String itemId,
    required CertificateImportItemUpdatePayload payload,
  });

  Future<CertificateImportBatchModel> submitBatch(String batchId);

  Future<CertificateImportItemModel> resubmitItem({
    required String batchId,
    required String itemId,
    required CertificateImportItemUpdatePayload payload,
  });
}

class CertificateImportRemoteDataSourceImpl
    implements CertificateImportRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  CertificateImportRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  String get _endpoint => '$_baseUrl${ApiEndpoints.certificateBulkImports}';

  @override
  Future<CertificateImportBatchModel> createBatch({
    required List<CertificateImportFilePayload> files,
  }) async {
    final response = await _dio.post(
      _endpoint,
      data: {'files': files.map((file) => file.toJson()).toList()},
    );
    return CertificateImportBatchModel.fromJson(_data(response));
  }

  @override
  Future<CertificateImportBatchModel> processOcr(String batchId) async {
    final response = await _dio.post('$_endpoint/$batchId/process-ocr');
    return CertificateImportBatchModel.fromJson(_data(response));
  }

  @override
  Future<CertificateImportBatchModel> getBatch(String batchId) async {
    final response = await _dio.get('$_endpoint/$batchId');
    return CertificateImportBatchModel.fromJson(_data(response));
  }

  @override
  Future<CertificateImportItemModel> updateItem({
    required String batchId,
    required String itemId,
    required CertificateImportItemUpdatePayload payload,
  }) async {
    final response = await _dio.patch(
      '$_endpoint/$batchId/items/$itemId',
      data: payload.toJson(),
    );
    return CertificateImportItemModel.fromJson(_data(response));
  }

  @override
  Future<CertificateImportBatchModel> submitBatch(String batchId) async {
    final response = await _dio.post('$_endpoint/$batchId/submit');
    return CertificateImportBatchModel.fromJson(_data(response));
  }

  @override
  Future<CertificateImportItemModel> resubmitItem({
    required String batchId,
    required String itemId,
    required CertificateImportItemUpdatePayload payload,
  }) async {
    final response = await _dio.post(
      '$_endpoint/$batchId/items/$itemId/resubmit',
      data: payload.toJson(),
    );
    return CertificateImportItemModel.fromJson(_data(response));
  }

  Map<String, dynamic> _data(Response<dynamic> response) {
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ServerException(
        message: 'Error al comunicarse con carga por certificado',
        code: response.statusCode,
      );
    }

    final body = response.data;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
    }

    throw ServerException(
        message: 'Respuesta inválida de carga por certificado');
  }
}
