import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/certificate_import_batch.dart';
import '../../domain/entities/certificate_import_batch_list.dart';
import '../../domain/entities/certificate_import_error_code.dart';
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
    } catch (error) {
      return Left(_toFailure(error));
    }
  }

  Future<Either<Failure, CertificateImportItem>> _item(
    Future<dynamic> Function() action,
  ) async {
    try {
      final model = await action();
      return Right(model.toEntity() as CertificateImportItem);
    } catch (error) {
      return Left(_toFailure(error));
    }
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } catch (error) {
      return Left(_toFailure(error));
    }
  }

  /// Classifies [error] without leaking backend text: [Failure.message] is
  /// always translated app copy, and the business code (if any) goes in
  /// [Failure.errorCode] for the presentation mapper.
  Failure _toFailure(Object error) {
    final fallback = 'certificate_import.errors.unexpected.body'.tr();
    if (error is DioException) {
      final body = error.response?.data;
      final code = CertificateImportErrorCode.known(
            body is Map ? body['code'] : null,
          ) ??
          CertificateImportErrorCode.known(
            body is Map ? body['message'] : null,
          );
      final wrapped = error.error;
      final noResponse = error.response == null;
      final isTimeout = error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout;
      final networkCode = !noResponse
          ? null
          : isTimeout
              ? CertificateImportErrorCode.timeout
              : error.type == DioExceptionType.connectionError ||
                      wrapped is ConnectionException
                  ? CertificateImportErrorCode.network
                  : null;
      if (wrapped is AuthException && code == null) {
        return AuthFailure(message: fallback, code: wrapped.code);
      }
      return ServerFailure(
        message: fallback,
        code: error.response?.statusCode,
        errorCode: code ?? networkCode,
      );
    }
    if (error is ServerException) {
      return ServerFailure(
        message: fallback,
        code: error.code,
        errorCode: CertificateImportErrorCode.known(error.errorCode) ??
            CertificateImportErrorCode.known(error.message),
      );
    }
    if (error is AuthException) {
      return AuthFailure(message: fallback, code: error.code);
    }
    if (error is ConnectionException) {
      return ServerFailure(
        message: fallback,
        errorCode: CertificateImportErrorCode.network,
      );
    }
    return UnexpectedFailure(message: fallback);
  }
}
