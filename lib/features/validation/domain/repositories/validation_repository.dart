import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/validation.dart';

abstract class ValidationRepository {
  /// Envía una entidad a revisión.
  Future<Either<Failure, ValidationSubmitResult>> submitForReview({
    required ValidationEntityType entityType,
    required int entityId,
  });

  /// Obtiene el historial de validaciones de una entidad.
  Future<Either<Failure, List<ValidationHistoryEntry>>> getValidationHistory({
    required ValidationEntityType entityType,
    required int entityId,
  });

  /// Comprueba elegibilidad para investidura de un usuario.
  Future<Either<Failure, EligibilityResult>> checkEligibility({
    required String userId,
  });
}
