import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso para iniciar sesión con correo o usuario (handle) y contraseña
class SignIn implements UseCase<UserEntity, SignInParams> {
  final AuthRepository repository;

  SignIn(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(SignInParams params) {
    return repository.signInWithIdentifier(
      identifier: params.identifier,
      password: params.password,
    );
  }
}

/// Parámetros para el caso de uso SignIn
class SignInParams extends Equatable {
  /// Correo electrónico o usuario (handle) tal como lo escribió la persona,
  /// sin validar formato: el servidor decide cuál es (FP3-08).
  final String identifier;
  final String password;

  const SignInParams({
    required this.identifier,
    required this.password,
  });

  @override
  List<Object> get props => [identifier, password];
}
