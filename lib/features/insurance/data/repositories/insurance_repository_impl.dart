import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/insurance_overview.dart';
import '../../domain/entities/member_insurance.dart';
import '../../domain/repositories/insurance_repository.dart';
import '../datasources/insurance_remote_data_source.dart';

class InsuranceRepositoryImpl implements InsuranceRepository {
  InsuranceRepositoryImpl({required this.remoteDataSource});

  final InsuranceRemoteDataSource remoteDataSource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Right(await body());
    } on ServerException catch (e) {
      return Left(
        ServerFailure(
          message: e.message,
          code: e.code,
          errorCode: e.errorCode,
        ),
      );
    } on ConnectionException catch (e) {
      return Left(ConnectionFailure(message: e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, InsuranceOverview>> getOverview({
    required int sectionId,
    RequestCancelToken? cancelToken,
  }) {
    return _guard(
      () => remoteDataSource.getOverview(
        sectionId: sectionId,
        cancelToken: cancelToken.asDioCancelToken(),
      ),
    );
  }

  @override
  Future<Either<Failure, List<FreeCoverage>>> getFreeCoverages({
    required int sectionId,
    RequestCancelToken? cancelToken,
  }) {
    return _guard(
      () => remoteDataSource.getFreeCoverages(
        sectionId: sectionId,
        cancelToken: cancelToken.asDioCancelToken(),
      ),
    );
  }

  @override
  Future<Either<Failure, List<MemberInsurance>>> getMembersInsurance({
    required int clubId,
    required int sectionId,
    RequestCancelToken? cancelToken,
  }) {
    return _guard(() async {
      final models = await remoteDataSource.getMembersInsurance(
        clubId: clubId,
        sectionId: sectionId,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return models.map((m) => m.toEntity()).toList();
    });
  }
}
