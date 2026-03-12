import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

/// Parámetros para el caso de uso SwitchContext
class SwitchContextParams extends Equatable {
  final String assignmentId;

  const SwitchContextParams({required this.assignmentId});

  @override
  List<Object?> get props => [assignmentId];
}

/// Caso de uso para cambiar el contexto activo de autorización del usuario.
///
/// Llama a PATCH /auth/me/context con el assignment_id indicado.
/// Tras el éxito, el llamador debe refrescar el estado de autenticación
/// invocando getCurrentUser() para propagar los nuevos permisos.
class SwitchContext implements UseCase<void, SwitchContextParams> {
  final AuthRepository repository;

  SwitchContext(this.repository);

  @override
  Future<Either<Failure, void>> call(SwitchContextParams params) {
    return repository.switchContext(params.assignmentId);
  }
}
