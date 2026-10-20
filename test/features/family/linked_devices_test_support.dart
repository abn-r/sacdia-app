import 'package:dartz/dartz.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/family/domain/entities/linked_device.dart';
import 'package:sacdia_app/features/family/domain/repositories/linked_devices_repository.dart';

LinkedDevice linkedDevice(
  String id, {
  String label = 'Tablet de Ana',
  String platform = 'android',
  DateTime? lastSeenAt,
  DateTime? revokedAt,
  String pairedBy = 'María Pérez',
}) =>
    LinkedDevice(
      id: id,
      label: label,
      platform: platform,
      appVersion: '2.4.0',
      pairedAt: DateTime.utc(2026, 10, 20, 9),
      pairedByDisplayName: pairedBy,
      lastSeenAt: lastSeenAt,
      absoluteExpiresAt: DateTime.utc(2027, 4, 18),
      revokedAt: revokedAt,
    );

/// Repositorio configurable que registra cada llamada.
class FakeLinkedDevicesRepository implements LinkedDevicesRepository {
  Either<Failure, LinkedDevices> devices = const Right(LinkedDevices());
  Either<Failure, RevokedDevice>? revokeResult;
  Either<Failure, DevicePairingToken>? tokenResult;

  /// Se llama en cada `list` (para simular que aparece un teléfono nuevo).
  void Function()? onList;

  final listCalls = <String>[];
  final issueCalls = <String>[];
  final revokeCalls = <({String dependentId, String deviceId})>[];
  DateTime Function() now = DateTime.now;
  int issued = 0;

  @override
  Future<Either<Failure, LinkedDevices>> list(String dependentId) async {
    listCalls.add(dependentId);
    onList?.call();
    return devices;
  }

  @override
  Future<Either<Failure, DevicePairingToken>> issuePairingToken(
    String dependentId,
  ) async {
    issueCalls.add(dependentId);
    issued++;
    final fixed = tokenResult;
    if (fixed != null) return fixed;
    final at = now();
    return Right(DevicePairingToken(
      token: 'TOKEN-$issued',
      qrPayload: 'sacdia://pair?c=TOKEN-$issued',
      issuedAt: at,
      expiresAt: at.add(const Duration(minutes: 10)),
    ));
  }

  @override
  Future<Either<Failure, RevokedDevice>> revoke(
    String dependentId,
    String deviceId,
  ) async {
    revokeCalls.add((dependentId: dependentId, deviceId: deviceId));
    return revokeResult ??
        Right(RevokedDevice(
          linkedDeviceId: deviceId,
          revokedAt: DateTime.utc(2026, 10, 20, 12),
        ));
  }
}
