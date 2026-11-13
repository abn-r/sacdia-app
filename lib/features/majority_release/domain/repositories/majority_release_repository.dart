import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/adult_claim_code.dart';
import '../entities/released_entry.dart';

/// Llamadas de la liberación por mayoría de edad (Fase 4) que no son de
/// aceptación legal (esa reutiliza `features/legal`).
abstract class MajorityReleaseRepository {
  /// `POST /users/me/release/email`: agrega el correo de la persona liberada
  /// (uno sin verificar basta, R5).
  Future<Either<Failure, void>> addEmail(String email);

  /// `POST /auth/adult-claim/redeem` (PÚBLICO): canjea el código, crea las
  /// credenciales y el correo. No devuelve tokens: la persona inicia sesión.
  Future<Either<Failure, void>> redeemAdultClaim({
    required String code,
    required String email,
    required String password,
  });

  /// `GET /guardianships/me/history`.
  Future<Either<Failure, List<ReleasedEntry>>> getReleasedHistory();

  /// `POST /guardianships/me/released/:dependentId/adult-claim-code` (ex tutor).
  Future<Either<Failure, IssuedAdultClaimCode>> issueGuardianCode(
    String dependentId,
  );

  /// `POST /club-sections/:clubSectionId/dependents/:userId/adult-claim-codes`
  /// (director con `club_members:approve`).
  Future<Either<Failure, IssuedAdultClaimCode>> issueDirectorCode({
    required int clubSectionId,
    required String dependentUserId,
  });
}
