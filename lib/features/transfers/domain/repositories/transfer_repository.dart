import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/transfer_club_option.dart';
import '../entities/transfer_request.dart';

abstract class TransferRepository {
  /// Crea una nueva solicitud de traslado.
  Future<Either<Failure, TransferRequest>> createTransferRequest({
    required int fromSectionId,
    required int toSectionId,
    String? reason,
  });

  /// Lista las solicitudes de traslado del usuario actual.
  Future<Either<Failure, List<TransferRequest>>> getMyTransferRequests({
    RequestCancelToken? cancelToken,
  });

  /// Obtiene el detalle de una solicitud de traslado.
  Future<Either<Failure, TransferRequest>> getTransferRequest(
    String requestId, {
    RequestCancelToken? cancelToken,
  });

  /// Clubs of a local field the member can move to.
  Future<Either<Failure, List<TransferClubOption>>> getDestinationClubs({
    required int localFieldId,
    required int clubTypeId,
    RequestCancelToken? cancelToken,
  });
}
