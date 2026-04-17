import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/enrollment.dart';
import '../../domain/repositories/enrollment_repository.dart';
import '../datasources/enrollment_remote_data_source.dart';

class EnrollmentRepositoryImpl implements EnrollmentRepository {
  final EnrollmentRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  const EnrollmentRepositoryImpl({
    required EnrollmentRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

  @override
  Future<Either<Failure, Enrollment>> createEnrollment({
    required String clubId,
    required int sectionId,
    required String address,
    double? lat,
    double? long,
    required List<MeetingSchedule> meetingSchedule,
    int? soulsTarget,
    bool? fee,
    double? feeAmount,
    String? directorId,
    List<String> deputyDirectorIds = const [],
    String? secretaryId,
    String? treasurerId,
    String? secretaryTreasurerId,
  }) async {
    try {
      final model = await _remoteDataSource.createEnrollment(
        clubId: clubId,
        sectionId: sectionId,
        address: address,
        lat: lat,
        long: long,
        meetingSchedule: meetingSchedule,
        soulsTarget: soulsTarget,
        fee: fee,
        feeAmount: feeAmount,
        directorId: directorId,
        deputyDirectorIds: deputyDirectorIds,
        secretaryId: secretaryId,
        treasurerId: treasurerId,
        secretaryTreasurerId: secretaryTreasurerId,
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
  Future<Either<Failure, Enrollment?>> getCurrentEnrollment({
    required String clubId,
    required int sectionId,
    CancelToken? cancelToken,
  }) async {
    try {
      final model = await _remoteDataSource.getCurrentEnrollment(
        clubId: clubId,
        sectionId: sectionId,
        cancelToken: cancelToken,
      );
      return Right(model);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return Left(UnexpectedFailure(message: e.toString()));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Enrollment>> updateEnrollment({
    required String clubId,
    required int sectionId,
    required String enrollmentId,
    String? address,
    double? lat,
    double? long,
    List<MeetingSchedule>? meetingSchedule,
    int? soulsTarget,
    bool? fee,
    double? feeAmount,
    String? directorId,
    List<String>? deputyDirectorIds,
    String? secretaryId,
    String? treasurerId,
    String? secretaryTreasurerId,
  }) async {
    try {
      final model = await _remoteDataSource.updateEnrollment(
        clubId: clubId,
        sectionId: sectionId,
        enrollmentId: enrollmentId,
        address: address,
        lat: lat,
        long: long,
        meetingSchedule: meetingSchedule,
        soulsTarget: soulsTarget,
        fee: fee,
        feeAmount: feeAmount,
        directorId: directorId,
        deputyDirectorIds: deputyDirectorIds,
        secretaryId: secretaryId,
        treasurerId: treasurerId,
        secretaryTreasurerId: secretaryTreasurerId,
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
}
