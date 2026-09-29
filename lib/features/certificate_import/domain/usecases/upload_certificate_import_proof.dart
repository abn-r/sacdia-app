import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../entities/certificate_import_batch.dart';
import '../entities/certificate_import_payloads.dart';
import '../repositories/certificate_import_repository.dart';

class UploadCertificateImportProof {
  final CertificateImportRepository repository;

  UploadCertificateImportProof(this.repository);

  Future<Either<Failure, CertificateImportBatch>> call(
    CertificateImportLocalProof proof, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) {
    return repository.uploadLocalProof(
      proof,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}
