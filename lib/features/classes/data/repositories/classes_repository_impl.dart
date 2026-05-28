import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/progressive_class.dart';
import '../../domain/entities/class_module.dart';
import '../../domain/entities/class_progress.dart';
import '../../domain/entities/class_with_progress.dart';
import '../../domain/entities/requirement_evidence.dart';
import '../../domain/repositories/classes_repository.dart';
import '../datasources/classes_remote_data_source.dart';

/// Implementacion del repositorio de clases progresivas.
class ClassesRepositoryImpl implements ClassesRepository {
  final ClassesRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ClassesRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Left<Failure, T> _serverFailure<T>(ServerException e) =>
      Left(ServerFailure(message: e.message, code: e.code));

  Left<Failure, T> _authFailure<T>(AuthException e) =>
      Left(AuthFailure(message: e.message, code: e.code));

  Left<Failure, T> _unexpectedFailure<T>(Object e) =>
      Left(UnexpectedFailure(message: e.toString()));

  // ── Metodos de catalogo ───────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<ProgressiveClass>>> getClasses(
      {int? clubTypeId, CancelToken? cancelToken}) async {
    try {
      final models = await remoteDataSource.getClasses(
          clubTypeId: clubTypeId, cancelToken: cancelToken);
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return _unexpectedFailure(e);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, ProgressiveClass>> getClassById(int classId,
      {CancelToken? cancelToken}) async {
    try {
      final model = await remoteDataSource.getClassById(classId,
          cancelToken: cancelToken);
      return Right(model.toEntity());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return _unexpectedFailure(e);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, List<ClassModule>>> getClassModules(int classId,
      {CancelToken? cancelToken}) async {
    try {
      final models = await remoteDataSource.getClassModules(classId,
          cancelToken: cancelToken);
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return _unexpectedFailure(e);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, List<ProgressiveClass>>> getUserClasses(String userId,
      {CancelToken? cancelToken}) async {
    try {
      final models = await remoteDataSource.getUserClasses(userId,
          cancelToken: cancelToken);
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return _unexpectedFailure(e);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, ClassProgress>> getUserClassProgress(
      String userId, int classId,
      {int? enrollmentId, CancelToken? cancelToken}) async {
    try {
      final model = await remoteDataSource.getUserClassProgress(userId, classId,
          enrollmentId: enrollmentId, cancelToken: cancelToken);
      return Right(model.toEntity());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return _unexpectedFailure(e);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, ClassProgress>> updateUserClassProgress(
      String userId, int classId, Map<String, dynamic> progressData,
      {int? enrollmentId}) async {
    try {
      final model = await remoteDataSource.updateUserClassProgress(
          userId, classId, progressData,
          enrollmentId: enrollmentId);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  // ── Inscripcion en clases anteriores ─────────────────────────────────────────

  @override
  Future<Either<Failure, void>> enrollUser(
      String userId, int classId, int ecclesiasticalYearId) async {
    try {
      await remoteDataSource.enrollUser(userId, classId, ecclesiasticalYearId);
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  // ── Nuevas operaciones para flujo de evidencias ───────────────────────────────

  @override
  Future<Either<Failure, ClassWithProgress>> getClassWithProgress(
      String userId, int classId,
      {int? enrollmentId, CancelToken? cancelToken}) async {
    try {
      final model = await remoteDataSource.getClassWithProgress(userId, classId,
          enrollmentId: enrollmentId, cancelToken: cancelToken);
      return Right(model.toEntity());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return _unexpectedFailure(e);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> submitRequirement(
      String userId, int classId, int requirementId,
      {int? enrollmentId}) async {
    try {
      await remoteDataSource.submitRequirement(userId, classId, requirementId,
          enrollmentId: enrollmentId);
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, RequirementEvidence>> uploadRequirementFile({
    required String userId,
    required int classId,
    required int requirementId,
    required String filePath,
    required String fileName,
    required String mimeType,
    int? enrollmentId,
    void Function(double)? onProgress,
  }) async {
    try {
      final model = await remoteDataSource.uploadRequirementFile(
        userId: userId,
        classId: classId,
        requirementId: requirementId,
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
        enrollmentId: enrollmentId,
        onProgress: onProgress,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> deleteRequirementFile({
    required String userId,
    required int classId,
    required int requirementId,
    required String fileId,
    int? enrollmentId,
  }) async {
    try {
      await remoteDataSource.deleteRequirementFile(
        userId: userId,
        classId: classId,
        requirementId: requirementId,
        fileId: fileId,
        enrollmentId: enrollmentId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }
}
