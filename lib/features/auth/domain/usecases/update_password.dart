import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso para actualizar la contraseña del usuario autenticado.
/// Requiere la contraseña actual para re-autenticación.
class UpdatePassword implements UseCase<UserEntity, UpdatePasswordParams> {
  final AuthRepository repository;

  UpdatePassword(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(UpdatePasswordParams params) {
    return repository.updatePassword(
      params.currentPassword,
      params.newPassword,
    );
  }
}

/// Parámetros para el caso de uso UpdatePassword
class UpdatePasswordParams extends Equatable {
  final String currentPassword;
  final String newPassword;

  const UpdatePasswordParams({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object> get props => [currentPassword, newPassword];
}
