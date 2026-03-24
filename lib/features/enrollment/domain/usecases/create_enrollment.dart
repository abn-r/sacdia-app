import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/enrollment.dart';
import '../repositories/enrollment_repository.dart';

class CreateEnrollmentParams extends Equatable {
  final String clubId;
  final int sectionId;
  final String address;
  final List<String> meetingDays;

  const CreateEnrollmentParams({
    required this.clubId,
    required this.sectionId,
    required this.address,
    required this.meetingDays,
  });

  @override
  List<Object> get props => [clubId, sectionId, address, meetingDays];
}

class CreateEnrollment implements UseCase<Enrollment, CreateEnrollmentParams> {
  final EnrollmentRepository repository;

  CreateEnrollment(this.repository);

  @override
  Future<Either<Failure, Enrollment>> call(
      CreateEnrollmentParams params) async {
    return repository.createEnrollment(
      clubId: params.clubId,
      sectionId: params.sectionId,
      address: params.address,
      meetingDays: params.meetingDays,
    );
  }
}
