import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/transfer_request.dart';

abstract class TransferRepository {
  /// Crea una nueva solicitud de traslado.
  Future<Either<Failure, TransferRequest>> createTransferRequest({
    required int toSectionId,
    String? reason,
  });

  /// Lista las solicitudes de traslado del usuario actual.
  Future<Either<Failure, List<TransferRequest>>> getMyTransferRequests();

  /// Obtiene el detalle de una solicitud de traslado.
  Future<Either<Failure, TransferRequest>> getTransferRequest(int requestId);
}
