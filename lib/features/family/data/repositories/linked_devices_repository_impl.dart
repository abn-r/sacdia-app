import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/linked_device.dart';
import '../../domain/repositories/linked_devices_repository.dart';
import '../datasources/linked_devices_remote_data_source.dart';

class LinkedDevicesRepositoryImpl implements LinkedDevicesRepository {
  LinkedDevicesRepositoryImpl({required this.remoteDataSource});

  final LinkedDevicesRemoteDataSource remoteDataSource;

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
      return Left(UnexpectedFailure(message: e.runtimeType.toString()));
    }
  }

  @override
  Future<Either<Failure, LinkedDevices>> list(String dependentId) =>
      _guard(() => remoteDataSource.list(dependentId));

  @override
  Future<Either<Failure, DevicePairingToken>> issuePairingToken(
    String dependentId,
  ) =>
      _guard(() => remoteDataSource.issuePairingToken(dependentId));

  @override
  Future<Either<Failure, RevokedDevice>> revoke(
    String dependentId,
    String deviceId,
  ) =>
      _guard(() => remoteDataSource.revoke(dependentId, deviceId));
}
