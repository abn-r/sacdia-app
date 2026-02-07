import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/completion_status.dart';
import '../repositories/post_registration_repository.dart';

/// Caso de uso para obtener el estado de completitud del post-registro
class GetPostRegistrationStatus implements NoParamsUseCase<CompletionStatus> {
  final PostRegistrationRepository repository;

  GetPostRegistrationStatus(this.repository);

  @override
  Future<Either<Failure, CompletionStatus>> call() {
    return repository.getCompletionStatus();
  }
}
