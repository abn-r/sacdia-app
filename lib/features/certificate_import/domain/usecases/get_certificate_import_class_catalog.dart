import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/certificate_import_class_option.dart';
import '../repositories/certificate_import_repository.dart';

class GetCertificateImportClassCatalog {
  final CertificateImportRepository repository;

  GetCertificateImportClassCatalog(this.repository);

  Future<Either<Failure, List<CertificateImportClassOption>>> call(
    int clubTypeId, {
    RequestCancelToken? cancelToken,
  }) {
    return repository.getClassCatalog(
      clubTypeId: clubTypeId,
      cancelToken: cancelToken,
    );
  }
}
