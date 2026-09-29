import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/certificate_import_institutional_request.dart';
import '../repositories/certificate_import_repository.dart';

class ListCertificateImportInstitutionalRequests {
  final CertificateImportRepository repository;

  ListCertificateImportInstitutionalRequests(this.repository);

  Future<Either<Failure, CertificateImportInstitutionalRequestList>> call({
    int page = 1,
    int limit = 20,
  }) {
    return repository.listInstitutionalRequests(page: page, limit: limit);
  }
}
