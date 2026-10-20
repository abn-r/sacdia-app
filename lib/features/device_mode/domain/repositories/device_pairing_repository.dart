import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/device_pairing.dart';

abstract class DevicePairingRepository {
  /// `POST /auth/device/pair` (público). NO guarda nada: quien llama decide
  /// cuándo persistir los tokens.
  Future<Either<Failure, DevicePairingSession>> pair(DevicePairingInput input);
}
