import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/supervision_folder.dart';

abstract class SupervisionFoldersRepository {
  /// GET /annual-folders/evaluation/queue
  Future<Either<Failure, SupervisionFolderQueuePage>> getQueue({
    SupervisionFolderQueueFilter filter =
        SupervisionFolderQueueFilter.needsReview,
    int page = 1,
    int limit = 25,
    RequestCancelToken? cancelToken,
  });

  /// GET /annual-folders/:folderId
  Future<Either<Failure, SupervisionFolderDetail>> getFolder(
    String folderId, {
    RequestCancelToken? cancelToken,
  });

  /// POST /annual-folders/:folderId/sections/:sectionId/evaluate
  Future<Either<Failure, Unit>> evaluateSection(
    String folderId,
    String sectionId, {
    required int earnedPoints,
    String? notes,
    RequestCancelToken? cancelToken,
  });

  /// POST /annual-folders/:folderId/sections/:sectionId/reopen
  Future<Either<Failure, Unit>> reopenSection(
    String folderId,
    String sectionId, {
    RequestCancelToken? cancelToken,
  });

  /// POST /annual-folders/:folderId/sections/:sectionId/confirm-union
  Future<Either<Failure, Unit>> confirmUnion(
    String folderId,
    String sectionId, {
    required bool approve,
    String? notes,
    RequestCancelToken? cancelToken,
  });

  /// POST /annual-folders/:folderId/close
  Future<Either<Failure, Unit>> closeFolder(
    String folderId, {
    RequestCancelToken? cancelToken,
  });

  /// PATCH /annual-folders/evidences/:evidenceId/reviewer-note
  Future<Either<Failure, Unit>> saveReviewerNote(
    String evidenceId,
    String? note, {
    RequestCancelToken? cancelToken,
  });
}
