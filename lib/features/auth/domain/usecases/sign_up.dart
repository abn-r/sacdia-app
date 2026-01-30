import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso para registrar un nuevo usuario con email y contraseña
class SignUp implements UseCase<UserEntity, SignUpParams> {
  final AuthRepository repository;

  SignUp(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(SignUpParams params) {
    return repository.signUpWithEmailAndPassword(
      email: params.email,
      password: params.password,
      name: params.name,
      paternalSurname: params.paternalSurname,
      maternalSurname: params.maternalSurname,
    );
  }
}

/// Parámetros para el caso de uso SignUp
class SignUpParams extends Equatable {
  final String email;
  final String password;
  final String name;
  final String paternalSurname;
  final String maternalSurname;

  const SignUpParams({
    required this.email,
    required this.password,
    required this.name,
    required this.paternalSurname,
    required this.maternalSurname,
  });

  @override
  List<Object> get props => [email, password, name, paternalSurname, maternalSurname];
}
