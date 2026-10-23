import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/linked_device.dart';

/// Teléfonos vinculados de un menor, desde el perfil PROPIO del tutor (sin
/// `X-Acting-For`). Los fallos conservan [Failure.errorCode]
/// (`DEVICE_LIMIT_REACHED`, `DEVICE_PAIRING_NOT_ELIGIBLE`, ...); el cliente no
/// lee `details`.
abstract class LinkedDevicesRepository {
  /// `GET /guardianships/me/dependents/:id/devices`.
  Future<Either<Failure, LinkedDevices>> list(String dependentId);

  /// `POST /guardianships/me/dependents/:id/devices/pairing-tokens`.
  Future<Either<Failure, DevicePairingToken>> issuePairingToken(
    String dependentId,
  );

  /// `POST /guardianships/me/dependents/:id/devices/:deviceId/revoke`
  /// (idempotente).
  Future<Either<Failure, RevokedDevice>> revoke(
    String dependentId,
    String deviceId,
  );
}
