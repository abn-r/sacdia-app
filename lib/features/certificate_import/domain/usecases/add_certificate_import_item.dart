import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/certificate_import_item.dart';
import '../entities/certificate_import_payloads.dart';
import '../repositories/certificate_import_repository.dart';

class AddCertificateImportItem {
  final CertificateImportRepository repository;

  AddCertificateImportItem(this.repository);

  Future<Either<Failure, CertificateImportItem>> call(
    AddCertificateImportItemParams params,
  ) {
    return repository.addItem(
      batchId: params.batchId,
      payload: params.payload,
    );
  }
}

class AddCertificateImportItemParams {
  final String batchId;
  final CertificateImportItemUpdatePayload payload;

  const AddCertificateImportItemParams({
    required this.batchId,
    required this.payload,
  });
}
