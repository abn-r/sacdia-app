import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../domain/entities/transfer_club_option.dart';
import '../../domain/entities/transfer_request.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../datasources/transfer_remote_data_source.dart';

class TransferRepositoryImpl implements TransferRepository {
  final TransferRemoteDataSource _remoteDataSource;

  const TransferRepositoryImpl({
    required TransferRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, TransferRequest>> createTransferRequest({
    required int fromSectionId,
    required int toSectionId,
    String? reason,
  }) async {
    try {
      final model = await _remoteDataSource.createTransferRequest(
        fromSectionId: fromSectionId,
        toSectionId: toSectionId,
        reason: reason,
      );
      return Right(model);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransferRequest>>> getMyTransferRequests({
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final models = await _remoteDataSource.getMyTransferRequests(
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return Right(models);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransferRequest>> getTransferRequest(
    String requestId, {
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final model = await _remoteDataSource.getTransferRequest(
        requestId,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return Right(model);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransferClubOption>>> getDestinationClubs({
    required int localFieldId,
    required int clubTypeId,
    RequestCancelToken? cancelToken,
  }) async {
    try {
      return Right(await _remoteDataSource.getDestinationClubs(
        localFieldId: localFieldId,
        clubTypeId: clubTypeId,
        cancelToken: cancelToken.asDioCancelToken(),
      ));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
