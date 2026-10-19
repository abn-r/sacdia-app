import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/dependent.dart';
import '../../domain/repositories/family_repository.dart';
import '../datasources/family_remote_data_source.dart';

/// Repositorio de Mi familia. Conserva [Failure.errorCode] (`GUARDIANSHIP_*`)
/// para que la UI muestre el mensaje exacto; el cliente no lee `details`.
class FamilyRepositoryImpl implements FamilyRepository {
  final FamilyRemoteDataSource remoteDataSource;

  FamilyRepositoryImpl({required this.remoteDataSource});

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
  Future<Either<Failure, FamilyOverview>> listDependents() =>
      _guard(remoteDataSource.listDependents);

  @override
  Future<Either<Failure, DependentDetail>> getDependent(String dependentId) =>
      _guard(() => remoteDataSource.getDependent(dependentId));

  @override
  Future<Either<Failure, DependentSummary>> createDependent(
    CreateDependentInput input,
  ) =>
      _guard(() => remoteDataSource.createDependent(input));

  @override
  Future<Either<Failure, IssuedLinkCode>> issueLinkCode(String dependentId) =>
      _guard(() => remoteDataSource.issueLinkCode(dependentId));

  @override
  Future<Either<Failure, DependentSummary>> redeemLinkCode({
    required String code,
    required String relationshipTypeId,
    required bool swornDeclaration,
  }) =>
      _guard(
        () => remoteDataSource.redeemLinkCode(
          code: code,
          relationshipTypeId: relationshipTypeId,
          swornDeclaration: swornDeclaration,
        ),
      );

  @override
  Future<Either<Failure, RevokeResult>> revoke({
    required String guardianshipId,
    required bool removedByPrimary,
  }) =>
      _guard(
        () => remoteDataSource.revoke(
          guardianshipId: guardianshipId,
          removedByPrimary: removedByPrimary,
        ),
      );

  @override
  Future<Either<Failure, List<DeletionImpactEntry>>> deletionImpact() =>
      _guard(remoteDataSource.deletionImpact);
}
