import 'dart:io';

import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/certificate_import_batch_list_model.dart';
import '../models/certificate_import_batch_model.dart';
import '../models/certificate_import_file_model.dart';
import '../models/certificate_import_institutional_request_model.dart';
import '../models/certificate_import_item_model.dart';
import '../models/certificate_import_presign_ticket_model.dart';
import '../../domain/entities/certificate_import_payloads.dart';

abstract class CertificateImportRemoteDataSource {
  Future<CertificateImportBatchModel> createBatch({
    List<CertificateImportFilePayload> files = const [],
  });

  /// Create draft → presign → PUT to R2 (no API Authorization) → confirm.
  Future<CertificateImportBatchModel> uploadLocalProof(
    CertificateImportLocalProof proof, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  });

  Future<CertificateImportPresignTicketModel> presignFile({
    required String batchId,
    required String fileName,
    required String mimeType,
    required int fileSize,
  });

  Future<void> uploadToSignedUrl({
    required String uploadUrl,
    required String localPath,
    required String mimeType,
    Map<String, String> requiredHeaders = const {},
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  });

  Future<CertificateImportFileModel> confirmFile({
    required String batchId,
    required String fileId,
  });

  Future<CertificateImportBatchListModel> listBatches({
    int page = 1,
    int limit = 20,
  });

  Future<CertificateImportBatchModel> processOcr(String batchId);

  Future<CertificateImportBatchModel> getBatch(String batchId);

  /// Signed download of the sealed proof. Rejects anything that is not https.
  Future<String> signedDownloadUrl({
    required String batchId,
    required String fileId,
  });

  Future<CertificateImportItemModel> addItem({
    required String batchId,
    required CertificateImportItemUpdatePayload payload,
  });

  Future<void> removeItem({
    required String batchId,
    required String itemId,
  });

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

  /// Ready against GET /api/v1/certificate-import-institutional-requests.
  Future<CertificateImportInstitutionalRequestListModel>
      listInstitutionalRequests({
    int page = 1,
    int limit = 20,
  });
}

class CertificateImportRemoteDataSourceImpl
    implements CertificateImportRemoteDataSource {
  final Dio _dio;
  final Dio _uploadDio;
  final String _baseUrl;

  CertificateImportRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
    Dio? uploadDio,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        // Plain Dio — must not carry API Authorization / refresh interceptors.
        _uploadDio = uploadDio ?? Dio();

  String get _endpoint => '$_baseUrl${ApiEndpoints.certificateBulkImports}';

  String get _institutionalEndpoint =>
      '$_baseUrl/certificate-import-institutional-requests';

  @override
  Future<CertificateImportBatchModel> createBatch({
    List<CertificateImportFilePayload> files = const [],
  }) async {
    final remoteFiles = files.where((file) => file.isRemoteUrl).toList();
    final response = await _dio.post(
      _endpoint,
      data: {
        'files': remoteFiles.map((file) => file.toJson()).toList(),
      },
    );
    return CertificateImportBatchModel.fromJson(_data(response));
  }

  @override
  Future<CertificateImportBatchModel> uploadLocalProof(
    CertificateImportLocalProof proof, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final batch = await createBatch(files: const []);
    final ticket = await presignFile(
      batchId: batch.id,
      fileName: proof.fileName,
      mimeType: proof.mimeType,
      fileSize: proof.fileSize,
    );
    await uploadToSignedUrl(
      uploadUrl: ticket.uploadUrl,
      localPath: proof.localPath,
      mimeType: proof.mimeType,
      requiredHeaders: ticket.requiredHeaders,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    await confirmFile(batchId: batch.id, fileId: ticket.fileId);
    return getBatch(batch.id);
  }

  @override
  Future<CertificateImportPresignTicketModel> presignFile({
    required String batchId,
    required String fileName,
    required String mimeType,
    required int fileSize,
  }) async {
    final response = await _dio.post(
      '$_endpoint/$batchId/files/presign',
      data: {
        'file_name': fileName,
        'mime_type': mimeType,
        'file_size': fileSize,
      },
    );
    return CertificateImportPresignTicketModel.fromJson(_data(response));
  }

  @override
  Future<void> uploadToSignedUrl({
    required String uploadUrl,
    required String localPath,
    required String mimeType,
    Map<String, String> requiredHeaders = const {},
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final bytes = await File(localPath).readAsBytes();
    final headers = <String, dynamic>{
      'Content-Type': mimeType,
      'Content-Length': bytes.length.toString(),
      ...requiredHeaders,
    };
    // Never attach API Authorization to the signed R2 PUT.
    headers.remove('Authorization');
    headers.remove('authorization');

    await _uploadDio.put<void>(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      cancelToken: cancelToken,
      options: Options(
        headers: headers,
        // Absolute R2 URL — do not inherit API baseUrl or auth interceptors.
        followRedirects: false,
      ),
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );
  }

  @override
  Future<CertificateImportFileModel> confirmFile({
    required String batchId,
    required String fileId,
  }) async {
    final response = await _dio.post(
      '$_endpoint/$batchId/files/$fileId/confirm',
    );
    return CertificateImportFileModel.fromJson(_data(response));
  }

  @override
  Future<CertificateImportBatchListModel> listBatches({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      _endpoint,
      queryParameters: {'page': page, 'limit': limit},
    );
    return CertificateImportBatchListModel.fromJson(_data(response));
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
  Future<String> signedDownloadUrl({
    required String batchId,
    required String fileId,
  }) async {
    final response = await _dio.get(
      '$_endpoint/$batchId/files/$fileId/download',
    );
    final url = _data(response)['download_url'];
    if (url is! String || !url.startsWith('https://')) {
      throw ServerException(
        message: 'CERTIFICATE_IMPORT_FILE_NOT_CONFIRMED',
      );
    }
    return url;
  }

  @override
  Future<CertificateImportItemModel> addItem({
    required String batchId,
    required CertificateImportItemUpdatePayload payload,
  }) async {
    final response = await _dio.post(
      '$_endpoint/$batchId/items',
      data: payload.toJson(),
    );
    return CertificateImportItemModel.fromJson(_data(response));
  }

  @override
  Future<void> removeItem({
    required String batchId,
    required String itemId,
  }) async {
    final response = await _dio.delete('$_endpoint/$batchId/items/$itemId');
    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw ServerException(
        message: 'Error al quitar la fila del expediente',
        code: response.statusCode,
      );
    }
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

  @override
  Future<CertificateImportInstitutionalRequestListModel>
      listInstitutionalRequests({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      _institutionalEndpoint,
      queryParameters: {'page': page, 'limit': limit},
    );
    return CertificateImportInstitutionalRequestListModel.fromJson(
      _data(response),
    );
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
