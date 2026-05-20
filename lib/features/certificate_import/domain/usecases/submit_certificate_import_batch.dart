import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/certificate_import_batch.dart';
import '../repositories/certificate_import_repository.dart';

class SubmitCertificateImportBatch {
  final CertificateImportRepository repository;

  SubmitCertificateImportBatch(this.repository);

  Future<Either<Failure, CertificateImportBatch>> call(String batchId) {
    return repository.submitBatch(batchId);
  }
}
