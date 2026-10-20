import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/teen_supervision.dart';
import '../../domain/repositories/teen_repository.dart';
import '../datasources/teen_remote_data_source.dart';

/// Repositorio del adolescente. Conserva [Failure.errorCode] para que la UI
/// muestre el mensaje exacto por `code`; nunca lee `details`.
class TeenRepositoryImpl implements TeenRepository {
  final TeenRemoteDataSource remoteDataSource;

  TeenRepositoryImpl({required this.remoteDataSource});

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
  Future<Either<Failure, TeenSupervision>> getSupervision() =>
      _guard(remoteDataSource.getSupervision);

  @override
  Future<Either<Failure, TeenLinkCode>> issueLinkCode() =>
      _guard(remoteDataSource.issueLinkCode);

  @override
  Future<Either<Failure, void>> revokePendingLink(String guardianshipId) =>
      _guard(() => remoteDataSource.revokePendingLink(guardianshipId));
}
