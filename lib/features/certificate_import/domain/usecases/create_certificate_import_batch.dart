import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../data/datasources/certificate_import_remote_data_source.dart';
import '../entities/certificate_import_batch.dart';
import '../repositories/certificate_import_repository.dart';

class CreateCertificateImportBatch {
  final CertificateImportRepository repository;

  CreateCertificateImportBatch(this.repository);

  Future<Either<Failure, CertificateImportBatch>> call(
    CreateCertificateImportBatchParams params,
  ) {
    return repository.createBatch(files: params.files);
  }
}

class CreateCertificateImportBatchParams {
  final List<CertificateImportFilePayload> files;

  const CreateCertificateImportBatchParams({required this.files});
}
