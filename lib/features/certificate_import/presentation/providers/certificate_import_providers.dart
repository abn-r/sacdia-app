import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/certificate_import_remote_data_source.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/certificate_import_repository_impl.dart';
import '../../domain/entities/certificate_import_batch.dart';
import '../../domain/entities/certificate_import_batch_list.dart';
import '../../domain/entities/certificate_import_institutional_request.dart';
import '../../domain/repositories/certificate_import_repository.dart';
import '../../domain/usecases/add_certificate_import_item.dart';
import '../../domain/usecases/create_certificate_import_batch.dart';
import '../../domain/usecases/get_certificate_import_batch.dart';
import '../../domain/usecases/list_certificate_import_batches.dart';
import '../../domain/usecases/list_certificate_import_institutional_requests.dart';
import '../../domain/usecases/process_certificate_import_ocr.dart';
import '../../domain/usecases/signed_certificate_import_download.dart';
import '../../domain/usecases/remove_certificate_import_item.dart';
import '../../domain/usecases/resubmit_certificate_import_item.dart';
import '../../domain/usecases/submit_certificate_import_batch.dart';
import '../../domain/usecases/update_certificate_import_item.dart';
import '../../domain/usecases/upload_certificate_import_proof.dart';

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

final uploadCertificateImportProofProvider =
    Provider<UploadCertificateImportProof>((ref) {
  return UploadCertificateImportProof(
      ref.read(certificateImportRepositoryProvider));
});

final listCertificateImportBatchesProvider =
    Provider<ListCertificateImportBatches>((ref) {
  return ListCertificateImportBatches(
      ref.read(certificateImportRepositoryProvider));
});

final listCertificateImportInstitutionalRequestsProvider =
    Provider<ListCertificateImportInstitutionalRequests>((ref) {
  return ListCertificateImportInstitutionalRequests(
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

final signedCertificateImportDownloadProvider =
    Provider<SignedCertificateImportDownload>((ref) {
  return SignedCertificateImportDownload(
      ref.read(certificateImportRepositoryProvider));
});

final addCertificateImportItemProvider =
    Provider<AddCertificateImportItem>((ref) {
  return AddCertificateImportItem(
      ref.read(certificateImportRepositoryProvider));
});

final removeCertificateImportItemProvider =
    Provider<RemoveCertificateImportItem>((ref) {
  return RemoveCertificateImportItem(
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

final certificateImportBatchListProvider = FutureProvider.autoDispose
    .family<CertificateImportBatchList, ({int page, int limit})>(
        (ref, args) async {
  final result = await ref.read(listCertificateImportBatchesProvider).call(
        page: args.page,
        limit: args.limit,
      );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (list) => list,
  );
});

final certificateImportInstitutionalRequestsProvider = FutureProvider
    .autoDispose
    .family<CertificateImportInstitutionalRequestList, ({int page, int limit})>(
        (ref, args) async {
  final result =
      await ref.read(listCertificateImportInstitutionalRequestsProvider).call(
            page: args.page,
            limit: args.limit,
          );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (list) => list,
  );
});
