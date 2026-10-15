import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/honors_repository.dart';

/// Retira la propuesta de instructor pendiente de una especialidad aprobada.
class CancelHonorInstructorProposal
    implements UseCase<void, CancelHonorInstructorProposalParams> {
  final HonorsRepository repository;

  CancelHonorInstructorProposal(this.repository);

  @override
  Future<Either<Failure, void>> call(
      CancelHonorInstructorProposalParams params) {
    return repository.cancelHonorInstructorProposal(
        params.userId, params.honorId);
  }
}

class CancelHonorInstructorProposalParams {
  final String userId;
  final int honorId;

  const CancelHonorInstructorProposalParams({
    required this.userId,
    required this.honorId,
  });
}
