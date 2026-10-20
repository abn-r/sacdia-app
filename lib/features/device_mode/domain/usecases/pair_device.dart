import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/device_pairing.dart';
import '../repositories/device_pairing_repository.dart';

/// Canjea el token del QR por la sesión del teléfono vinculado.
class PairDevice implements UseCase<DevicePairingSession, DevicePairingInput> {
  final DevicePairingRepository repository;

  PairDevice(this.repository);

  @override
  Future<Either<Failure, DevicePairingSession>> call(
    DevicePairingInput params,
  ) =>
      repository.pair(params);
}
