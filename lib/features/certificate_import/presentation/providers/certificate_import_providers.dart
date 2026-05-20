import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/certificate_import_remote_data_source.dart';
import '../../data/repositories/certificate_import_repository_impl.dart';
import '../../domain/entities/certificate_import_batch.dart';
import '../../domain/repositories/certificate_import_repository.dart';
import '../../domain/usecases/create_certificate_import_batch.dart';
import '../../domain/usecases/get_certificate_import_batch.dart';
import '../../domain/usecases/process_certificate_import_ocr.dart';
import '../../domain/usecases/resubmit_certificate_import_item.dart';
import '../../domain/usecases/submit_certificate_import_batch.dart';
import '../../domain/usecases/update_certificate_import_item.dart';

final certificateImportRemoteDataSourceProvider =
    Provider<CertificateImportRemoteDataSource>((ref) {
  return CertificateImportRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final certificateImportRepositoryProvider =
    Provider<CertificateImportRepository>((ref) {
  return CertificateImportRepositoryImpl(
    remoteDataSource: ref.read(certificateImportRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

final createCertificateImportBatchProvider =
    Provider<CreateCertificateImportBatch>((ref) {
  return CreateCertificateImportBatch(
      ref.read(certificateImportRepositoryProvider));
});

final processCertificateImportOcrProvider =
    Provider<ProcessCertificateImportOcr>((ref) {
  return ProcessCertificateImportOcr(
      ref.read(certificateImportRepositoryProvider));
});

final getCertificateImportBatchProvider =
    Provider<GetCertificateImportBatch>((ref) {
  return GetCertificateImportBatch(
      ref.read(certificateImportRepositoryProvider));
});

final updateCertificateImportItemProvider =
    Provider<UpdateCertificateImportItem>((ref) {
  return UpdateCertificateImportItem(
      ref.read(certificateImportRepositoryProvider));
});

final submitCertificateImportBatchProvider =
    Provider<SubmitCertificateImportBatch>((ref) {
  return SubmitCertificateImportBatch(
      ref.read(certificateImportRepositoryProvider));
});

final resubmitCertificateImportItemProvider =
    Provider<ResubmitCertificateImportItem>((ref) {
  return ResubmitCertificateImportItem(
      ref.read(certificateImportRepositoryProvider));
});

final certificateImportBatchProvider = FutureProvider.autoDispose
    .family<CertificateImportBatch, String>((ref, batchId) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final result = await ref
      .read(getCertificateImportBatchProvider)
      .call(batchId, cancelToken: cancelToken);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (batch) => batch,
  );
});
