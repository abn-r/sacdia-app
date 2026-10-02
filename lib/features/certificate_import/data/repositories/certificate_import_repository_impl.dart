import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/certificate_import_batch.dart';
import '../../domain/entities/certificate_import_batch_list.dart';
import '../../domain/entities/certificate_import_institutional_request.dart';
import '../../domain/entities/certificate_import_item.dart';
import '../../domain/entities/certificate_import_payloads.dart';
import '../../domain/repositories/certificate_import_repository.dart';
import '../datasources/certificate_import_remote_data_source.dart';

class CertificateImportRepositoryImpl implements CertificateImportRepository {
  final CertificateImportRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  CertificateImportRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, CertificateImportBatch>> createBatch({
    List<CertificateImportFilePayload> files = const [],
  }) async {
    return _batch(() => remoteDataSource.createBatch(files: files));
  }

  @override
  Future<Either<Failure, CertificateImportBatch>> uploadLocalProof(
    CertificateImportLocalProof proof, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) {
    return _batch(
      () => remoteDataSource.uploadLocalProof(
        proof,
        onProgress: onProgress,
        cancelToken: cancelToken,
      ),
    );
  }

  @override
  Future<Either<Failure, CertificateImportBatchList>> listBatches({
    int page = 1,
    int limit = 20,
  }) {
    return _guard(() async {
      final model =
          await remoteDataSource.listBatches(page: page, limit: limit);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, CertificateImportBatch>> processOcr(String batchId) {
    return _batch(() => remoteDataSource.processOcr(batchId));
  }

  @override
  Future<Either<Failure, CertificateImportBatch>> getBatch(
    String batchId, {
    RequestCancelToken? cancelToken,
  }) {
    return _batch(() => remoteDataSource.getBatch(batchId));
  }

  @override
  Future<Either<Failure, String>> signedDownloadUrl({
    required String batchId,
    required String fileId,
  }) {
    return _guard(
      () => remoteDataSource.signedDownloadUrl(
        batchId: batchId,
        fileId: fileId,
      ),
    );
  }

  @override
  Future<Either<Failure, CertificateImportItem>> addItem({
    required String batchId,
    required CertificateImportItemUpdatePayload payload,
  }) {
    return _item(
      () => remoteDataSource.addItem(batchId: batchId, payload: payload),
    );
  }

  @override
  Future<Either<Failure, void>> removeItem({
    required String batchId,
    required String itemId,
  }) {
    return _guard(() async {
      await remoteDataSource.removeItem(batchId: batchId, itemId: itemId);
    });
  }

  @override
  Future<Either<Failure, CertificateImportItem>> updateItem({
    required String batchId,
    required String itemId,
    required CertificateImportItemUpdatePayload payload,
  }) {
    return _item(
      () => remoteDataSource.updateItem(
        batchId: batchId,
        itemId: itemId,
        payload: payload,
      ),
    );
  }

  @override
  Future<Either<Failure, CertificateImportBatch>> submitBatch(String batchId) {
    return _batch(() => remoteDataSource.submitBatch(batchId));
  }

  @override
  Future<Either<Failure, CertificateImportItem>> resubmitItem({
    required String batchId,
    required String itemId,
    required CertificateImportItemUpdatePayload payload,
  }) {
    return _item(
      () => remoteDataSource.resubmitItem(
        batchId: batchId,
        itemId: itemId,
        payload: payload,
      ),
    );
  }

  @override
  Future<Either<Failure, CertificateImportInstitutionalRequestList>>
      listInstitutionalRequests({
    int page = 1,
    int limit = 20,
  }) {
    return _guard(() async {
      final model = await remoteDataSource.listInstitutionalRequests(
        page: page,
        limit: limit,
      );
      return model.toEntity();
    });
  }

  Future<Either<Failure, CertificateImportBatch>> _batch(
    Future<dynamic> Function() action,
  ) async {
    try {
      final model = await action();
      return Right(model.toEntity() as CertificateImportBatch);
    } on ServerException catch (error) {
      return Left(ServerFailure(message: error.message, code: error.code));
    } on AuthException catch (error) {
      return Left(AuthFailure(message: error.message, code: error.code));
    } on DioException catch (error) {
      final body = error.response?.data;
      final responseCode = body is Map ? body['code'] : null;
      final responseMessage = body is Map ? body['message'] : null;
      // Legacy BadRequest responses expose the business code as message.
      // Keep only these known codes; never surface parser details or paths.
      const pdfCodes = <String>{
        'CERTIFICATE_IMPORT_PDF_TOO_MANY_PAGES',
        'CERTIFICATE_IMPORT_PDF_INVALID',
        'CERTIFICATE_IMPORT_PDF_ENCRYPTED',
      };
      final businessCode = pdfCodes.contains(responseCode)
          ? responseCode as String
          : pdfCodes.contains(responseMessage)
              ? responseMessage as String
              : null;
      final wrappedError = error.error;
      final friendlyMessage = responseMessage is String
          ? responseMessage
          : wrappedError is AppException
              ? wrappedError.message
              : error.message ?? 'Error de red';
      return Left(ServerFailure(
        message: businessCode ?? friendlyMessage,
        code: error.response?.statusCode,
      ));
    } catch (error) {
      return Left(UnexpectedFailure(message: error.toString()));
    }
  }

  Future<Either<Failure, CertificateImportItem>> _item(
    Future<dynamic> Function() action,
  ) async {
    try {
      final model = await action();
      return Right(model.toEntity() as CertificateImportItem);
    } on ServerException catch (error) {
      return Left(ServerFailure(message: error.message, code: error.code));
    } on AuthException catch (error) {
      return Left(AuthFailure(message: error.message, code: error.code));
    } on DioException catch (error) {
      return Left(
        ServerFailure(
            message: error.message ?? 'Error de red',
            code: error.response?.statusCode),
      );
    } catch (error) {
      return Left(UnexpectedFailure(message: error.toString()));
    }
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (error) {
      return Left(ServerFailure(message: error.message, code: error.code));
    } on AuthException catch (error) {
      return Left(AuthFailure(message: error.message, code: error.code));
    } on DioException catch (error) {
      return Left(
        ServerFailure(
            message: error.message ?? 'Error de red',
            code: error.response?.statusCode),
      );
    } catch (error) {
      return Left(UnexpectedFailure(message: error.toString()));
    }
  }
}
