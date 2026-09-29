import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/certificate_import_batch.dart';
import '../entities/certificate_import_batch_list.dart';
import '../entities/certificate_import_institutional_request.dart';
import '../entities/certificate_import_item.dart';
import '../entities/certificate_import_payloads.dart';

abstract class CertificateImportRepository {
  Future<Either<Failure, CertificateImportBatch>> createBatch({
    List<CertificateImportFilePayload> files = const [],
  });

  Future<Either<Failure, CertificateImportBatch>> uploadLocalProof(
    CertificateImportLocalProof proof, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  });

  Future<Either<Failure, CertificateImportBatchList>> listBatches({
    int page = 1,
    int limit = 20,
  });

  Future<Either<Failure, CertificateImportBatch>> processOcr(String batchId);

  Future<Either<Failure, CertificateImportBatch>> getBatch(
    String batchId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, String>> signedDownloadUrl({
    required String batchId,
    required String fileId,
  });

  Future<Either<Failure, CertificateImportItem>> addItem({
    required String batchId,
    required CertificateImportItemUpdatePayload payload,
  });

  Future<Either<Failure, void>> removeItem({
    required String batchId,
    required String itemId,
  });

  Future<Either<Failure, CertificateImportItem>> updateItem({
    required String batchId,
    required String itemId,
    required CertificateImportItemUpdatePayload payload,
  });

  Future<Either<Failure, CertificateImportBatch>> submitBatch(String batchId);

  Future<Either<Failure, CertificateImportItem>> resubmitItem({
    required String batchId,
    required String itemId,
    required CertificateImportItemUpdatePayload payload,
  });

  Future<Either<Failure, CertificateImportInstitutionalRequestList>>
      listInstitutionalRequests({
    int page = 1,
    int limit = 20,
  });
}
