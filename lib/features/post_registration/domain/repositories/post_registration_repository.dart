import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/completion_status.dart';

/// Interfaz del repositorio de post-registro
abstract class PostRegistrationRepository {
  /// Obtiene el estado de completitud del post-registro
  Future<Either<Failure, CompletionStatus>> getCompletionStatus();

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
  });
}
