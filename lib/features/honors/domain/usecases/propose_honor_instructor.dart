import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/widgets/instructor_selection.dart';
import '../entities/instructor_proposal.dart';
import '../repositories/honors_repository.dart';

/// Propone un instructor en una especialidad ya aprobada (D11).
class ProposeHonorInstructor
    implements UseCase<InstructorProposal, ProposeHonorInstructorParams> {
  final HonorsRepository repository;

  ProposeHonorInstructor(this.repository);

  @override
  Future<Either<Failure, InstructorProposal>> call(
      ProposeHonorInstructorParams params) {
    return repository.proposeHonorInstructor(
        params.userId, params.honorId, params.instructor);
  }
}

class ProposeHonorInstructorParams {
  final String userId;
  final int honorId;
  final InstructorSelection instructor;

  const ProposeHonorInstructorParams({
    required this.userId,
    required this.honorId,
    required this.instructor,
  });
}
