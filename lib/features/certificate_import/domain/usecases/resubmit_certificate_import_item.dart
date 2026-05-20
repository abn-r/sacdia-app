import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../data/datasources/certificate_import_remote_data_source.dart';
import '../entities/certificate_import_item.dart';
import '../repositories/certificate_import_repository.dart';

class ResubmitCertificateImportItem {
  final CertificateImportRepository repository;

  ResubmitCertificateImportItem(this.repository);

  Future<Either<Failure, CertificateImportItem>> call(
    ResubmitCertificateImportItemParams params,
  ) {
    return repository.resubmitItem(
      batchId: params.batchId,
      itemId: params.itemId,
      payload: params.payload,
    );
  }
}

class ResubmitCertificateImportItemParams {
  final String batchId;
  final String itemId;
  final CertificateImportItemUpdatePayload payload;

  const ResubmitCertificateImportItemParams({
    required this.batchId,
    required this.itemId,
    required this.payload,
  });
}
