import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../data/datasources/certificate_import_remote_data_source.dart';
import '../entities/certificate_import_item.dart';
import '../repositories/certificate_import_repository.dart';

class UpdateCertificateImportItem {
  final CertificateImportRepository repository;

  UpdateCertificateImportItem(this.repository);

  Future<Either<Failure, CertificateImportItem>> call(
    UpdateCertificateImportItemParams params,
  ) {
    return repository.updateItem(
      batchId: params.batchId,
      itemId: params.itemId,
      payload: params.payload,
    );
  }
}

class UpdateCertificateImportItemParams {
  final String batchId;
  final String itemId;
  final CertificateImportItemUpdatePayload payload;

  const UpdateCertificateImportItemParams({
    required this.batchId,
    required this.itemId,
    required this.payload,
  });
}
