import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/adult_claim_code.dart';
import '../../domain/entities/released_entry.dart';
import '../../domain/repositories/majority_release_repository.dart';
import '../datasources/majority_release_remote_data_source.dart';

/// Repositorio de la liberación por mayoría de edad. Conserva
/// [Failure.errorCode] para que la UI muestre el mensaje exacto por `code`.
class MajorityReleaseRepositoryImpl implements MajorityReleaseRepository {
  final MajorityReleaseRemoteDataSource remoteDataSource;

  MajorityReleaseRepositoryImpl({required this.remoteDataSource});

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        code: e.code,
        errorCode: e.errorCode,
      ));
    } on AuthException catch (e) {
      return Left(AuthFailure(
        message: e.message,
        code: e.code,
        errorCode: e.errorCode,
      ));
    } on ConnectionException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addEmail(String email) =>
      _guard(() => remoteDataSource.addEmail(email));

  @override
  Future<Either<Failure, void>> redeemAdultClaim({
    required String code,
    required String email,
    required String password,
  }) =>
      _guard(
        () => remoteDataSource.redeemAdultClaim(
          code: code,
          email: email,
          password: password,
        ),
      );

  @override
  Future<Either<Failure, List<ReleasedEntry>>> getReleasedHistory() =>
      _guard(remoteDataSource.getReleasedHistory);

  @override
  Future<Either<Failure, IssuedAdultClaimCode>> issueGuardianCode(
    String dependentId,
  ) =>
      _guard(() => remoteDataSource.issueGuardianCode(dependentId));

  @override
  Future<Either<Failure, IssuedAdultClaimCode>> issueDirectorCode({
    required int clubSectionId,
    required String dependentUserId,
  }) =>
      _guard(
        () => remoteDataSource.issueDirectorCode(
          clubSectionId: clubSectionId,
          dependentUserId: dependentUserId,
        ),
      );
}
