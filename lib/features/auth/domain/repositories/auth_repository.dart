import 'package:dartz/dartz.dart';
import '../../../../core/auth/social_credential.dart';
import '../../../../core/errors/failures.dart';
import '../entities/delete_account_reauth.dart';
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
    required String acceptedTermsVersion,
    required String acceptedPrivacyVersion,
    String? birthday,
  });

  /// Cierra la sesión del usuario actual
  Future<Either<Failure, void>> signOut();

  /// Solicita un correo de recuperación de contraseña
  Future<Either<Failure, void>> resetPassword(String email);

  /// Actualiza la contraseña del usuario
  Future<Either<Failure, UserEntity>> updatePassword(
      String currentPassword, String newPassword);

  /// Inicia sesión con Google (SDK nativo). Devuelve [SocialSignInCancelledFailure]
  /// si el usuario cancela.
  Future<Either<Failure, UserEntity>> signInWithGoogle();

  /// Inicia sesión con Apple (SDK nativo). Devuelve [SocialSignInCancelledFailure]
  /// si el usuario cancela.
  Future<Either<Failure, UserEntity>> signInWithApple();

  /// Obtiene el estado de completitud del post-registro
  Future<Either<Failure, bool>> getCompletionStatus();

  /// Verifica si hay un token guardado localmente (sin llamar al API)
  Future<bool> hasLocalToken();

  /// Cambia el contexto activo de autorización del usuario.
  Future<Either<Failure, void>> switchContext(String assignmentId);

  /// Elimina permanentemente la cuenta del usuario autenticado.
  ///
  /// Requiere reautenticación server-side: la contraseña actual o un idToken
  /// fresco del proveedor social ([DeleteAccountReauth]).
  /// El backend aplica cascada: revoca sesiones, borra PII, archiva audit log.
  Future<Either<Failure, void>> deleteAccount(DeleteAccountReauth reauth);

  /// Proveedores sociales vinculados a la cuenta del usuario autenticado.
  Future<Either<Failure, List<SocialProvider>>> getConnectedProviders();
}
