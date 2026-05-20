import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/certificate_import_batch.dart';
import '../../domain/entities/certificate_import_item.dart';
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
    required List<CertificateImportFilePayload> files,
  }) async {
    return _batch(() => remoteDataSource.createBatch(files: files));
  }

  @override
  Future<Either<Failure, CertificateImportBatch>> processOcr(String batchId) {
    return _batch(() => remoteDataSource.processOcr(batchId));
  }

  @override
  Future<Either<Failure, CertificateImportBatch>> getBatch(
    String batchId, {
    CancelToken? cancelToken,
  }) {
    return _batch(() => remoteDataSource.getBatch(batchId));
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
      return Left(
        ServerFailure(
            message: error.message ?? 'Error de red',
            code: error.response?.statusCode),
      );
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
}
