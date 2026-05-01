import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/honor.dart';
import '../../domain/entities/honor_category.dart';
import '../../domain/entities/honor_group.dart';
import '../../domain/entities/honor_requirement.dart';
import '../../domain/entities/requirement_evidence.dart';
import '../../domain/entities/user_honor.dart';
import '../../domain/entities/user_honor_requirement_progress.dart';
import '../../domain/repositories/honors_repository.dart';
import '../../domain/usecases/register_user_honor.dart';
import '../datasources/honors_remote_data_source.dart';

/// Implementación del repositorio de especialidades
class HonorsRepositoryImpl implements HonorsRepository {
  final HonorsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  HonorsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<HonorCategory>>> getHonorCategories({CancelToken? cancelToken}) async {
    try {
      final categoryModels = await remoteDataSource.getHonorCategories(cancelToken: cancelToken);
      final categories = categoryModels.map((model) => model.toEntity()).toList();
      return Right(categories);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Honor>>> getHonors({
    int? categoryId,
    int? clubTypeId,
    int? skillLevel,
    CancelToken? cancelToken,
  }) async {
    try {
      final honorModels = await remoteDataSource.getHonors(
        categoryId: categoryId,
        clubTypeId: clubTypeId,
        skillLevel: skillLevel,
        cancelToken: cancelToken,
      );
      final honors = honorModels.map((model) => model.toEntity()).toList();
      return Right(honors);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Honor>> getHonorById(int honorId, {CancelToken? cancelToken}) async {
    try {
      final honorModel = await remoteDataSource.getHonorById(honorId, cancelToken: cancelToken);
      return Right(honorModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<UserHonor>>> getUserHonors(String userId, {CancelToken? cancelToken}) async {
    try {
      final userHonorModels = await remoteDataSource.getUserHonors(userId, cancelToken: cancelToken);
      final userHonors = userHonorModels.map((model) => model.toEntity()).toList();
      return Right(userHonors);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUserHonorStats(String userId, {CancelToken? cancelToken}) async {
    try {
      final stats = await remoteDataSource.getUserHonorStats(userId, cancelToken: cancelToken);
      return Right(stats);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserHonor>> enrollUserInHonor(String userId, int honorId) async {
    try {
      final userHonorModel = await remoteDataSource.enrollUserInHonor(userId, honorId);
      return Right(userHonorModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserHonor>> updateUserHonor(
    String userId,
    int honorId,
    Map<String, dynamic> data,
  ) async {
    try {
      final userHonorModel = await remoteDataSource.updateUserHonor(userId, honorId, data);
      return Right(userHonorModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUserHonor(String userId, int honorId) async {
    try {
      await remoteDataSource.deleteUserHonor(userId, honorId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserHonor>> registerUserHonor(
    RegisterUserHonorParams params,
  ) async {
    try {
      final model = await remoteDataSource.registerUserHonor(params);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<HonorGroup>>> getHonorsGroupedByCategory({CancelToken? cancelToken}) async {
    try {
      final groupModels = await remoteDataSource.getHonorsGroupedByCategory(cancelToken: cancelToken);
      final groups = groupModels.map((model) => model.toEntity()).toList();
      return Right(groups);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<HonorRequirement>>> getHonorRequirements(
      int honorId, {CancelToken? cancelToken}) async {
    try {
      final requirementModels =
          await remoteDataSource.getHonorRequirements(honorId, cancelToken: cancelToken);
      final requirements =
          requirementModels.map((model) => model.toEntity()).toList();
      return Right(requirements);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<UserHonorRequirementProgress>>> getUserHonorProgress(
      String userId, int honorId, {CancelToken? cancelToken}) async {
    try {
      final models = await remoteDataSource.getUserHonorProgress(userId, honorId, cancelToken: cancelToken);
      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserHonorRequirementProgress>> updateRequirementProgress({
    required int honorId,
    required int requirementId,
    required bool completed,
    String? notes,
  }) async {
    try {
      final model = await remoteDataSource.updateRequirementProgress(
        honorId: honorId,
        requirementId: requirementId,
        completed: completed,
        notes: notes,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<UserHonorRequirementProgress>>> bulkUpdateRequirementProgress(
      String userId,
      int honorId,
      List<Map<String, dynamic>> updates) async {
    try {
      final models = await remoteDataSource.bulkUpdateRequirementProgress(
          userId, honorId, updates);
      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, RequirementEvidence>> uploadRequirementEvidence(
    String userId,
    int honorId,
    int requirementId,
    File file, {
    required String mimeType,
  }) async {
    try {
      final model = await remoteDataSource.uploadRequirementEvidence(
          userId, honorId, requirementId, file, mimeType: mimeType);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, RequirementEvidence>> addRequirementEvidenceLink(
    String userId,
    int honorId,
    int requirementId,
    String url,
  ) async {
    try {
      final model = await remoteDataSource.addRequirementEvidenceLink(
          userId, honorId, requirementId, url);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<RequirementEvidence>>> getRequirementEvidences(
    String userId,
    int honorId,
    int requirementId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final models = await remoteDataSource.getRequirementEvidences(
          userId, honorId, requirementId, cancelToken: cancelToken);
      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRequirementEvidence(
    String userId,
    int honorId,
    int requirementId,
    int evidenceId,
  ) async {
    try {
      await remoteDataSource.deleteRequirementEvidence(
          userId, honorId, requirementId, evidenceId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
