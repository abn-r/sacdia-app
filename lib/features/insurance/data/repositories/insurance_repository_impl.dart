import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/member_insurance.dart';
import '../../domain/repositories/insurance_repository.dart';
import '../datasources/insurance_remote_data_source.dart';

/// Implementación del repositorio de seguros.
class InsuranceRepositoryImpl implements InsuranceRepository {
  final InsuranceRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  InsuranceRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<MemberInsurance>>> getMembersInsurance({
    required int clubId,
    required int sectionId,
    CancelToken? cancelToken,
  }) async {
    try {
      final models = await remoteDataSource.getMembersInsurance(
        clubId: clubId,
        sectionId: sectionId,
        cancelToken: cancelToken,
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
  Future<Either<Failure, MemberInsurance>> getMemberInsuranceDetail({
    required String memberId,
    CancelToken? cancelToken,
  }) async {
    try {
      final model = await remoteDataSource.getMemberInsuranceDetail(
        memberId: memberId,
        cancelToken: cancelToken,
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
  Future<Either<Failure, MemberInsurance>> createInsurance({
    required String memberId,
    required InsuranceType insuranceType,
    required DateTime startDate,
    required DateTime endDate,
    String? policyNumber,
    String? providerName,
    double? coverageAmount,
    String? evidenceFilePath,
    String? evidenceFileName,
    String? evidenceMimeType,
  }) async {
    try {
      final model = await remoteDataSource.createInsurance(
        memberId: memberId,
        insuranceType: insuranceType,
        startDate: startDate,
        endDate: endDate,
        policyNumber: policyNumber,
        providerName: providerName,
        coverageAmount: coverageAmount,
        evidenceFilePath: evidenceFilePath,
        evidenceFileName: evidenceFileName,
        evidenceMimeType: evidenceMimeType,
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
  Future<Either<Failure, MemberInsurance>> updateInsurance({
    required int insuranceId,
    InsuranceType? insuranceType,
    DateTime? startDate,
    DateTime? endDate,
    String? policyNumber,
    String? providerName,
    double? coverageAmount,
    String? evidenceFilePath,
    String? evidenceFileName,
    String? evidenceMimeType,
  }) async {
    try {
      final model = await remoteDataSource.updateInsurance(
        insuranceId: insuranceId,
        insuranceType: insuranceType,
        startDate: startDate,
        endDate: endDate,
        policyNumber: policyNumber,
        providerName: providerName,
        coverageAmount: coverageAmount,
        evidenceFilePath: evidenceFilePath,
        evidenceFileName: evidenceFileName,
        evidenceMimeType: evidenceMimeType,
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
  Future<Either<Failure, List<MemberInsurance>>> getExpiringInsurance({
    required int days,
    CancelToken? cancelToken,
  }) async {
    try {
      final models = await remoteDataSource.getExpiringInsurance(
        days: days,
        cancelToken: cancelToken,
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
}
