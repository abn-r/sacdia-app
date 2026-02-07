import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso para verificar sesión existente
///
/// Usado por la pantalla de splash para determinar el estado de autenticación
class CheckSession implements NoParamsUseCase<UserEntity?> {
  final AuthRepository repository;

  CheckSession(this.repository);

  @override
  Future<Either<Failure, UserEntity?>> call() {
    return repository.getCurrentUser();
  }
}
