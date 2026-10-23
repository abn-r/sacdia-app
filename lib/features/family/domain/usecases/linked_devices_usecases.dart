import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/linked_device.dart';
import '../repositories/linked_devices_repository.dart';

/// Lista los teléfonos vinculados de un menor.
class ListLinkedDevices implements UseCase<LinkedDevices, String> {
  final LinkedDevicesRepository repository;

  ListLinkedDevices(this.repository);

  @override
  Future<Either<Failure, LinkedDevices>> call(String dependentId) =>
      repository.list(dependentId);
}

/// Pide el token (y el QR) para vincular un teléfono nuevo.
class IssueDevicePairingToken implements UseCase<DevicePairingToken, String> {
  final LinkedDevicesRepository repository;

  IssueDevicePairingToken(this.repository);

  @override
  Future<Either<Failure, DevicePairingToken>> call(String dependentId) =>
      repository.issuePairingToken(dependentId);
}

class RevokeLinkedDeviceParams extends Equatable {
  final String dependentId;
  final String deviceId;

  const RevokeLinkedDeviceParams({
    required this.dependentId,
    required this.deviceId,
  });

  @override
  List<Object?> get props => [dependentId, deviceId];
}

/// Desvincula un teléfono; el corte es inmediato en el servidor.
class RevokeLinkedDevice
    implements UseCase<RevokedDevice, RevokeLinkedDeviceParams> {
  final LinkedDevicesRepository repository;

  RevokeLinkedDevice(this.repository);

  @override
  Future<Either<Failure, RevokedDevice>> call(
    RevokeLinkedDeviceParams params,
  ) =>
      repository.revoke(params.dependentId, params.deviceId);
}
