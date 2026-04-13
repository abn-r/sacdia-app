import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/enrollment.dart';
import '../repositories/enrollment_repository.dart';

class GetCurrentEnrollmentParams extends Equatable {
  final String clubId;
  final int sectionId;

  const GetCurrentEnrollmentParams({
    required this.clubId,
    required this.sectionId,
  });

  @override
  List<Object> get props => [clubId, sectionId];
}

class GetCurrentEnrollment
    implements UseCase<Enrollment?, GetCurrentEnrollmentParams> {
  final EnrollmentRepository repository;

  GetCurrentEnrollment(this.repository);

  @override
  Future<Either<Failure, Enrollment?>> call(
      GetCurrentEnrollmentParams params, {CancelToken? cancelToken}) async {
    return repository.getCurrentEnrollment(
      clubId: params.clubId,
      sectionId: params.sectionId,
      cancelToken: cancelToken,
    );
  }
}
