import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../data/datasources/certificate_import_remote_data_source.dart';
import '../entities/certificate_import_batch.dart';
import '../entities/certificate_import_item.dart';

abstract class CertificateImportRepository {
  Future<Either<Failure, CertificateImportBatch>> createBatch({
    required List<CertificateImportFilePayload> files,
  });

  Future<Either<Failure, CertificateImportBatch>> processOcr(String batchId);

  Future<Either<Failure, CertificateImportBatch>> getBatch(
    String batchId, {
    CancelToken? cancelToken,
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
}
