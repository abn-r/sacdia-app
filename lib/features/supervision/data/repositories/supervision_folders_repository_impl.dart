import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/supervision_folder.dart';
import '../../domain/repositories/supervision_folders_repository.dart';
import '../datasources/supervision_folders_remote_data_source.dart';

class SupervisionFoldersRepositoryImpl implements SupervisionFoldersRepository {
  final SupervisionFoldersRemoteDataSource remoteDataSource;

  SupervisionFoldersRepositoryImpl({required this.remoteDataSource});

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
    } on ServerException catch (e) {
      return Left(ServerFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } on AuthException catch (e) {
      return Left(AuthFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } on ConnectionException catch (e) {
      return Left(ConnectionFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  Future<Either<Failure, Unit>> _guardVoid(Future<void> Function() call) =>
      _guard(() async {
        await call();
        return unit;
      });

  @override
  Future<Either<Failure, SupervisionFolderQueuePage>> getQueue({
    SupervisionFolderQueueFilter filter =
        SupervisionFolderQueueFilter.needsReview,
    int page = 1,
    int limit = 25,
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getQueue(
            filter: filter,
            page: page,
            limit: limit,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, SupervisionFolderDetail>> getFolder(
    String folderId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getFolder(
            folderId,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, Unit>> evaluateSection(
    String folderId,
    String sectionId, {
    required int earnedPoints,
    String? notes,
    RequestCancelToken? cancelToken,
  }) =>
      _guardVoid(() => remoteDataSource.evaluateSection(
            folderId,
            sectionId,
            earnedPoints: earnedPoints,
            notes: notes,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, Unit>> reopenSection(
    String folderId,
    String sectionId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guardVoid(() => remoteDataSource.reopenSection(
            folderId,
            sectionId,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, Unit>> confirmUnion(
    String folderId,
    String sectionId, {
    required bool approve,
    String? notes,
    RequestCancelToken? cancelToken,
  }) =>
      _guardVoid(() => remoteDataSource.confirmUnion(
            folderId,
            sectionId,
            approve: approve,
            notes: notes,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, Unit>> closeFolder(
    String folderId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guardVoid(() => remoteDataSource.closeFolder(
            folderId,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, Unit>> saveReviewerNote(
    String evidenceId,
    String? note, {
    RequestCancelToken? cancelToken,
  }) =>
      _guardVoid(() => remoteDataSource.saveReviewerNote(
            evidenceId,
            note,
            cancelToken: cancelToken.asDioCancelToken(),
          ));
}
