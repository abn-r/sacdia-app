import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/completion_status.dart';
import '../repositories/post_registration_repository.dart';

/// Caso de uso para obtener el estado de completitud del post-registro
class GetPostRegistrationStatus {
  final PostRegistrationRepository repository;

  GetPostRegistrationStatus(this.repository);

  Future<Either<Failure, CompletionStatus>> call({RequestCancelToken? cancelToken}) {
    return repository.getCompletionStatus(cancelToken: cancelToken);
  }
}
