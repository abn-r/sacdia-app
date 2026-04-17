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
  final double? lat;
  final double? long;
  final List<MeetingSchedule> meetingSchedule;
  final int? soulsTarget;
  final bool? fee;
  final double? feeAmount;
  final String? directorId;
  final List<String> deputyDirectorIds;
  final String? secretaryId;
  final String? treasurerId;
  final String? secretaryTreasurerId;

  const CreateEnrollmentParams({
    required this.clubId,
    required this.sectionId,
    required this.address,
    this.lat,
    this.long,
    required this.meetingSchedule,
    this.soulsTarget,
    this.fee,
    this.feeAmount,
    this.directorId,
    this.deputyDirectorIds = const [],
    this.secretaryId,
    this.treasurerId,
    this.secretaryTreasurerId,
  });

  @override
  List<Object?> get props => [
        clubId,
        sectionId,
        address,
        lat,
        long,
        meetingSchedule,
        soulsTarget,
        fee,
        feeAmount,
        directorId,
        deputyDirectorIds,
        secretaryId,
        treasurerId,
        secretaryTreasurerId,
      ];
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
      lat: params.lat,
      long: params.long,
      meetingSchedule: params.meetingSchedule,
      soulsTarget: params.soulsTarget,
      fee: params.fee,
      feeAmount: params.feeAmount,
      directorId: params.directorId,
      deputyDirectorIds: params.deputyDirectorIds,
      secretaryId: params.secretaryId,
      treasurerId: params.treasurerId,
      secretaryTreasurerId: params.secretaryTreasurerId,
    );
  }
}
