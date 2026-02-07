import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso para obtener el estado de completitud del post-registro
///
/// Retorna true si el post-registro está completo, false en caso contrario
class GetCompletionStatus implements NoParamsUseCase<bool> {
  final AuthRepository repository;

  GetCompletionStatus(this.repository);

  @override
  Future<Either<Failure, bool>> call() {
    return repository.getCompletionStatus();
  }
}
