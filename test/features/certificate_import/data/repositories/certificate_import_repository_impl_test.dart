import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certificate_import/data/datasources/certificate_import_remote_data_source.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:dio/dio.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_payloads.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_batch_list_model.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_batch_model.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_file_model.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_institutional_request_model.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_item_model.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_presign_ticket_model.dart';
import 'package:sacdia_app/features/certificate_import/data/repositories/certificate_import_repository_impl.dart';

class _NetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _RemoteDataSource implements CertificateImportRemoteDataSource {
  Object? error;

  @override
  Future<CertificateImportBatchModel> createBatch({
    List<CertificateImportFilePayload> files = const [],
  }) async {
    if (error != null) throw error!;
    return const CertificateImportBatchModel(id: 'batch-1', status: 'DRAFT');
  }

  @override
  Future<CertificateImportBatchModel> uploadLocalProof(
    CertificateImportLocalProof proof, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (error != null) throw error!;
    return const CertificateImportBatchModel(id: 'batch-1', status: 'DRAFT');
  }

  @override
  Future<CertificateImportPresignTicketModel> presignFile({
    required String batchId,
    required String fileName,
    required String mimeType,
    required int fileSize,
  }) async =>
      const CertificateImportPresignTicketModel(
        fileId: 'file-1',
        uploadUrl: 'https://r2.example/upload',
        expiresIn: 900,
      );

  @override
  Future<void> uploadToSignedUrl({
    required String uploadUrl,
    required String localPath,
    required String mimeType,
    Map<String, String> requiredHeaders = const {},
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {}

  @override
  Future<CertificateImportFileModel> confirmFile({
    required String batchId,
    required String fileId,
  }) async =>
      const CertificateImportFileModel(
        id: 'file-1',
        url: 'sealed/key',
        name: 'cert.jpg',
        type: 'image/jpeg',
      );

  @override
  Future<CertificateImportBatchListModel> listBatches({
    int page = 1,
    int limit = 20,
  }) async =>
      const CertificateImportBatchListModel(
        items: [],
        total: 0,
        page: 1,
        limit: 20,
      );

  @override
  Future<CertificateImportBatchModel> getBatch(String batchId) async =>
      const CertificateImportBatchModel(id: 'batch-1', status: 'DRAFT');

  @override
  Future<String> signedDownloadUrl({
    required String batchId,
    required String fileId,
  }) async =>
      'https://files.example/sealed';

  @override
  Future<CertificateImportBatchModel> processOcr(String batchId) async {
    throw ServerException(
      message: 'OCR no disponible. Completa el expediente manualmente.',
      code: 503,
    );
  }

  @override
  Future<CertificateImportItemModel> addItem({
    required String batchId,
    required CertificateImportItemUpdatePayload payload,
  }) async =>
      const CertificateImportItemModel(
        id: 'item-new',
        type: CertificateImportItemType.clazz,
        status: CertificateImportItemStatus.needsReview,
      );

  @override
  Future<void> removeItem({
    required String batchId,
    required String itemId,
  }) async {}

  @override
  Future<CertificateImportItemModel> resubmitItem({
    required String batchId,
    required String itemId,
    required CertificateImportItemUpdatePayload payload,
  }) async =>
      const CertificateImportItemModel(
        id: 'item-1',
        type: CertificateImportItemType.honor,
        status: CertificateImportItemStatus.resubmitted,
      );

  @override
  Future<CertificateImportBatchModel> submitBatch(String batchId) async =>
      const CertificateImportBatchModel(id: 'batch-1', status: 'SUBMITTED');

  @override
  Future<CertificateImportItemModel> updateItem({
    required String batchId,
    required String itemId,
    required CertificateImportItemUpdatePayload payload,
  }) async =>
      const CertificateImportItemModel(
        id: 'item-1',
        type: CertificateImportItemType.honor,
        status: CertificateImportItemStatus.ready,
      );

  @override
  Future<CertificateImportInstitutionalRequestListModel>
      listInstitutionalRequests({
    int page = 1,
    int limit = 20,
  }) async =>
      const CertificateImportInstitutionalRequestListModel(
        items: [],
        total: 0,
        page: 1,
        limit: 20,
      );
}

void main() {
  test('maps a successful create call to a domain entity', () async {
    final repository = CertificateImportRepositoryImpl(
      remoteDataSource: _RemoteDataSource(),
      networkInfo: _NetworkInfo(),
    );

    final result = await repository.createBatch(files: const []);

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('expected right'),
      (batch) => expect(batch.id, 'batch-1'),
    );
  });

  test('maps server exceptions to ServerFailure', () async {
    final remote = _RemoteDataSource()
      ..error = ServerException(message: 'Forbidden', code: 403);
    final repository = CertificateImportRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: _NetworkInfo(),
    );

    final result = await repository.createBatch(files: const []);

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) {
        expect(failure, isA<ServerFailure>());
        expect(failure.code, 403);
      },
      (_) => fail('expected failure'),
    );
  });
}
