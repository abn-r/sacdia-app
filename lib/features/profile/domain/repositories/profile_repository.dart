import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/user_detail.dart';

/// Interfaz del repositorio de perfil
abstract class ProfileRepository {
  /// Obtiene el perfil del usuario
  Future<Either<Failure, UserDetail>> getUserProfile(String userId);

  /// Actualiza el perfil del usuario
  Future<Either<Failure, UserDetail>> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  );

  /// Actualiza la foto de perfil del usuario
  Future<Either<Failure, String>> updateProfilePicture(
    String userId,
    String filePath,
  );
}
