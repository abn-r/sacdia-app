import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/certificate_import_repository.dart';

class SignedCertificateImportDownload {
  final CertificateImportRepository repository;

  SignedCertificateImportDownload(this.repository);

  Future<Either<Failure, String>> call({
    required String batchId,
    required String fileId,
  }) {
    return repository.signedDownloadUrl(batchId: batchId, fileId: fileId);
  }
}
