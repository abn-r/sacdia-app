import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

/// Interfaz del repositorio de autenticación para la capa de dominio
abstract class AuthRepository {
  /// Stream que emite el estado de autenticación del usuario
  Stream<bool> get authStateChanges;
  
  /// Obtiene el usuario actual o null si no hay sesión
  Future<Either<Failure, UserEntity?>> getCurrentUser();
  
  /// Inicia sesión con email y contraseña
  Future<Either<Failure, UserEntity>> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  
  /// Registra un nuevo usuario con email y contraseña
  Future<Either<Failure, UserEntity>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
  });
  
  /// Cierra la sesión del usuario actual
  Future<Either<Failure, void>> signOut();
  
  /// Solicita un correo de recuperación de contraseña
  Future<Either<Failure, void>> resetPassword(String email);
  
  /// Actualiza la contraseña del usuario
  Future<Either<Failure, UserEntity>> updatePassword(String newPassword);

  /// Inicia sesión con Google OAuth
  Future<Either<Failure, UserEntity>> signInWithGoogle();

  /// Inicia sesión con Apple OAuth
  Future<Either<Failure, UserEntity>> signInWithApple();

  /// Obtiene el estado de completitud del post-registro
  Future<Either<Failure, bool>> getCompletionStatus();

  /// Verifica si hay un token guardado localmente (sin llamar al API)
  Future<bool> hasLocalToken();

  /// Cambia el contexto activo de autorización del usuario.
  Future<Either<Failure, void>> switchContext(String assignmentId);

  /// Intercambia el access_token de Supabase (recibido por deep link OAuth)
  /// por el JWT interno de SACDIA y persiste la sesión.
  ///
  /// Llamar cuando Supabase dispara [onAuthStateChange] con evento signedIn
  /// después de un flujo OAuth. El backend en `/auth/oauth/callback` valida
  /// el token de Supabase y devuelve el JWT de SACDIA.
  Future<Either<Failure, UserEntity>> handleOAuthCallback(
    String supabaseAccessToken,
  );
}
