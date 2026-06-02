import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/completion_status.dart';

/// Interfaz del repositorio de post-registro
abstract class PostRegistrationRepository {
  /// Obtiene el estado de completitud del post-registro
  Future<Either<Failure, CompletionStatus>> getCompletionStatus({
    RequestCancelToken? cancelToken,
  });

  /// Sube la foto de perfil del usuario
  Future<Either<Failure, String>> uploadProfilePicture({
    required String userId,
    required String filePath,
  });

  /// Elimina la foto de perfil del usuario
  Future<Either<Failure, void>> deleteProfilePicture({
    required String userId,
  });

  /// Obtiene el estado de la foto de perfil
  Future<Either<Failure, bool>> getPhotoStatus({
    required String userId,
    RequestCancelToken? cancelToken,
  });

  /// Completa el paso 1 del post-registro
  Future<Either<Failure, void>> completeStep1(String userId);

  /// Cancela la solicitud pendiente de membresía y reabre selección de club.
  Future<Either<Failure, void>> cancelPendingMembershipRequest({
    required String userId,
  });
}
