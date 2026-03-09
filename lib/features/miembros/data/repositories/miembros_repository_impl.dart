import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/club_member.dart';
import '../../domain/entities/join_request.dart';
import '../../domain/repositories/miembros_repository.dart';
import '../datasources/miembros_remote_data_source.dart';

/// Implementación del repositorio de miembros
class MiembrosRepositoryImpl implements MiembrosRepository {
  final MiembrosRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  MiembrosRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<ClubMember>>> getClubMembers({
    required int clubId,
    required String instanceType,
    required int instanceId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final members = await remoteDataSource.getClubMembers(
        clubId: clubId,
        instanceType: instanceType,
        instanceId: instanceId,
      );
      return Right(members);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ClubMember>> getMemberDetail(String userId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final member = await remoteDataSource.getMemberDetail(userId);
      return Right(member);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<JoinRequest>>> getJoinRequests({
    required int clubId,
    required String instanceType,
    required int instanceId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final requests = await remoteDataSource.getJoinRequests(
        clubId: clubId,
        instanceType: instanceType,
        instanceId: instanceId,
      );
      return Right(requests);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, JoinRequest>> approveJoinRequest(
      String assignmentId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final request = await remoteDataSource.approveJoinRequest(assignmentId);
      return Right(request);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, JoinRequest>> rejectJoinRequest(
      String assignmentId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final request = await remoteDataSource.rejectJoinRequest(assignmentId);
      return Right(request);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> assignClubRole({
    required int clubId,
    required String instanceType,
    required int instanceId,
    required String userId,
    required String role,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final result = await remoteDataSource.assignClubRole(
        clubId: clubId,
        instanceType: instanceType,
        instanceId: instanceId,
        userId: userId,
        role: role,
      );
      return Right(result);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> removeClubRole(String assignmentId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final result = await remoteDataSource.removeClubRole(assignmentId);
      return Right(result);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
