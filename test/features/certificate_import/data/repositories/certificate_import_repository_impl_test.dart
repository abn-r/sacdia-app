import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/certificate_import/data/datasources/certificate_import_remote_data_source.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_batch_model.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_item_model.dart';
import 'package:sacdia_app/features/certificate_import/data/repositories/certificate_import_repository_impl.dart';

class _NetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _RemoteDataSource implements CertificateImportRemoteDataSource {
  Object? error;

  @override
  Future<CertificateImportBatchModel> createBatch({
    required List<CertificateImportFilePayload> files,
  }) async {
    if (error != null) throw error!;
    return const CertificateImportBatchModel(id: 'batch-1', status: 'DRAFT');
  }

  @override
  Future<CertificateImportBatchModel> getBatch(String batchId) async =>
      const CertificateImportBatchModel(id: 'batch-1', status: 'DRAFT');

  @override
  Future<CertificateImportBatchModel> processOcr(String batchId) async =>
      const CertificateImportBatchModel(id: 'batch-1', status: 'DRAFT');

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
}

void main() {
  test('maps a successful create call to a domain entity', () async {
    final repository = CertificateImportRepositoryImpl(
      remoteDataSource: _RemoteDataSource(),
      networkInfo: _NetworkInfo(),
    );

    final result = await repository.createBatch(
      files: const [
        CertificateImportFilePayload(
          url: 'https://cdn.sacdia.app/cert.jpg',
          name: 'cert.jpg',
          type: 'image/jpeg',
        ),
      ],
    );

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
