import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/certificate_import_batch_list.dart';
import '../repositories/certificate_import_repository.dart';

class ListCertificateImportBatches {
  final CertificateImportRepository repository;

  ListCertificateImportBatches(this.repository);

  Future<Either<Failure, CertificateImportBatchList>> call({
    int page = 1,
    int limit = 20,
  }) {
    return repository.listBatches(page: page, limit: limit);
  }
}
