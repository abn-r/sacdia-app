import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/repositories/activities_repository.dart';
import '../datasources/activities_remote_data_source.dart';
import '../models/create_activity_request.dart';

/// Implementación del repositorio de actividades
class ActivitiesRepositoryImpl implements ActivitiesRepository {
  final ActivitiesRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ActivitiesRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<Activity>>> getClubActivities(
    int clubId, {
    int? clubTypeId,
    int? activityTypeId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }

    try {
      final activityModels = await remoteDataSource.getClubActivities(
        clubId,
        clubTypeId: clubTypeId,
        activityTypeId: activityTypeId,
      );
      final activities = activityModels.map((model) => model.toEntity()).toList();
      return Right(activities);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Activity>> getActivityById(int activityId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }

    try {
      final activityModel = await remoteDataSource.getActivityById(activityId);
      return Right(activityModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Attendance>>> getActivityAttendance(int activityId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }

    try {
      final attendanceModels = await remoteDataSource.getActivityAttendance(activityId);
      final attendances = attendanceModels.map((model) => model.toEntity()).toList();
      return Right(attendances);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Activity>> createActivity({
    required int clubId,
    required CreateActivityRequest request,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }

    try {
      final activityModel = await remoteDataSource.createActivity(
        clubId: clubId,
        request: request,
      );
      return Right(activityModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Activity>> updateActivity({
    required int activityId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    bool? active,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }

    try {
      final activityModel = await remoteDataSource.updateActivity(
        activityId: activityId,
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        location: location,
        active: active,
      );
      return Right(activityModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteActivity(int activityId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }

    try {
      await remoteDataSource.deleteActivity(activityId);
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
  Future<Either<Failure, int>> registerAttendance(
    int activityId,
    List<String> userIds,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }

    try {
      final recordedCount = await remoteDataSource.registerAttendance(
        activityId,
        userIds,
      );
      return Right(recordedCount);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
