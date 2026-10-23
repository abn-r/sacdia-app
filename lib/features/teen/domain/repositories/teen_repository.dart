import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/teen_supervision.dart';

/// Endpoints del propio adolescente (`/users/me/...`).
///
/// Los fallos conservan [Failure.errorCode]; el cliente nunca lee `details`.
abstract class TeenRepository {
  /// `GET /users/me/supervision`.
  Future<Either<Failure, TeenSupervision>> getSupervision();

  /// `POST /users/me/guardian-link-codes`. El código en claro solo viene aquí.
  Future<Either<Failure, TeenLinkCode>> issueLinkCode();

  /// `POST /users/me/guardian-links/:guardianshipId/revoke`: quita un vínculo
  /// PENDIENTE que el propio adolescente inició.
  Future<Either<Failure, void>> revokePendingLink(String guardianshipId);
}
