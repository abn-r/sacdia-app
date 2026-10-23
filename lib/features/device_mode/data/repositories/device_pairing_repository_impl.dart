import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/device_pairing.dart';
import '../../domain/repositories/device_pairing_repository.dart';
import '../datasources/device_pairing_remote_data_source.dart';

/// Conserva [Failure.errorCode] (`DEVICE_PAIRING_TOKEN_INVALID`,
/// `DEVICE_LIMIT_REACHED`...) para que la UI muestre el mensaje exacto. Nunca
/// lee `details`.
class DevicePairingRepositoryImpl implements DevicePairingRepository {
  DevicePairingRepositoryImpl({required this.remoteDataSource});

  final DevicePairingRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, DevicePairingSession>> pair(
    DevicePairingInput input,
  ) async {
    try {
      return Right(await remoteDataSource.pair(input));
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
      return Left(UnexpectedFailure(message: e.runtimeType.toString()));
    }
  }
}
