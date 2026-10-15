import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/certificate_import_repository.dart';

/// Deletes a DRAFT batch the member walked away from.
class DeleteCertificateImportBatch {
  final CertificateImportRepository repository;

  DeleteCertificateImportBatch(this.repository);

  Future<Either<Failure, void>> call(String batchId) {
    return repository.deleteBatch(batchId);
  }
}
