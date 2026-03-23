import 'package:dartz/dartz.dart' hide Unit;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/unit.dart';
import '../../domain/entities/unit_member.dart';
import '../../domain/entities/weekly_record.dart';
import '../../domain/repositories/units_repository.dart';
import '../datasources/units_remote_data_source.dart';

/// Implementación del repositorio de unidades.
class UnitsRepositoryImpl implements UnitsRepository {
  final UnitsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  UnitsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  // ── Unidades ──────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Unit>>> getClubUnits({
    required int clubId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final models = await remoteDataSource.getClubUnits(clubId: clubId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> getUnitDetail({
    required int clubId,
    required int unitId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final model = await remoteDataSource.getUnitDetail(
        clubId: clubId,
        unitId: unitId,
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
  Future<Either<Failure, Unit>> createUnit({
    required int clubId,
    required String name,
    required String captainId,
    required String secretaryId,
    required String advisorId,
    String? substituteAdvisorId,
    required int clubTypeId,
    int? clubSectionId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final model = await remoteDataSource.createUnit(
        clubId: clubId,
        name: name,
        captainId: captainId,
        secretaryId: secretaryId,
        advisorId: advisorId,
        substituteAdvisorId: substituteAdvisorId,
        clubTypeId: clubTypeId,
        clubSectionId: clubSectionId,
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
  Future<Either<Failure, Unit>> updateUnit({
    required int clubId,
    required int unitId,
    String? name,
    String? captainId,
    String? secretaryId,
    String? advisorId,
    String? substituteAdvisorId,
    int? clubTypeId,
    int? clubSectionId,
    bool? active,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final model = await remoteDataSource.updateUnit(
        clubId: clubId,
        unitId: unitId,
        name: name,
        captainId: captainId,
        secretaryId: secretaryId,
        advisorId: advisorId,
        substituteAdvisorId: substituteAdvisorId,
        clubTypeId: clubTypeId,
        clubSectionId: clubSectionId,
        active: active,
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
  Future<Either<Failure, void>> deleteUnit({
    required int clubId,
    required int unitId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      await remoteDataSource.deleteUnit(clubId: clubId, unitId: unitId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  // ── Miembros ──────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, UnitMember>> addUnitMember({
    required int clubId,
    required int unitId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final model = await remoteDataSource.addUnitMember(
        clubId: clubId,
        unitId: unitId,
        userId: userId,
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
  Future<Either<Failure, void>> removeUnitMember({
    required int clubId,
    required int unitId,
    required int memberId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      await remoteDataSource.removeUnitMember(
        clubId: clubId,
        unitId: unitId,
        memberId: memberId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  // ── Registros semanales ───────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<WeeklyRecord>>> getWeeklyRecords({
    required int clubId,
    required int unitId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final models = await remoteDataSource.getWeeklyRecords(
        clubId: clubId,
        unitId: unitId,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, WeeklyRecord>> createWeeklyRecord({
    required int clubId,
    required int unitId,
    required String userId,
    required int week,
    required int attendance,
    required int punctuality,
    required int points,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final model = await remoteDataSource.createWeeklyRecord(
        clubId: clubId,
        unitId: unitId,
        userId: userId,
        week: week,
        attendance: attendance,
        punctuality: punctuality,
        points: points,
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
  Future<Either<Failure, WeeklyRecord>> updateWeeklyRecord({
    required int clubId,
    required int unitId,
    required int recordId,
    int? attendance,
    int? punctuality,
    int? points,
    bool? active,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final model = await remoteDataSource.updateWeeklyRecord(
        clubId: clubId,
        unitId: unitId,
        recordId: recordId,
        attendance: attendance,
        punctuality: punctuality,
        points: points,
        active: active,
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
}
