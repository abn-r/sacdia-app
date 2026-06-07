import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/certificate_import_batch.dart';
import '../repositories/certificate_import_repository.dart';

class GetCertificateImportBatch {
  final CertificateImportRepository repository;

  GetCertificateImportBatch(this.repository);

  Future<Either<Failure, CertificateImportBatch>> call(
    String batchId, {
    RequestCancelToken? cancelToken,
  }) {
    return repository.getBatch(batchId, cancelToken: cancelToken);
  }
}
