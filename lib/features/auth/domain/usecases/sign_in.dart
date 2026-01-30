import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso para iniciar sesión con email y contraseña
class SignIn implements UseCase<UserEntity, SignInParams> {
  final AuthRepository repository;

  SignIn(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(SignInParams params) {
    return repository.signInWithEmailAndPassword(
      email: params.email,
      password: params.password,
    );
  }
}

/// Parámetros para el caso de uso SignIn
class SignInParams extends Equatable {
  final String email;
  final String password;

  const SignInParams({
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [email, password];
}
