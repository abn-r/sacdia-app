import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/certificate_import_repository.dart';

class RemoveCertificateImportItem {
  final CertificateImportRepository repository;

  RemoveCertificateImportItem(this.repository);

  Future<Either<Failure, void>> call(
    RemoveCertificateImportItemParams params,
  ) {
    return repository.removeItem(
      batchId: params.batchId,
      itemId: params.itemId,
    );
  }
}

class RemoveCertificateImportItemParams {
  final String batchId;
  final String itemId;

  const RemoveCertificateImportItemParams({
    required this.batchId,
    required this.itemId,
  });
}
