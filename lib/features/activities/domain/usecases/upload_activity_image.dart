import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/activities_repository.dart';

/// Caso de uso para subir una imagen asociada a una actividad.
class UploadActivityImage
    implements UseCase<String, UploadActivityImageParams> {
  final ActivitiesRepository repository;

  UploadActivityImage(this.repository);

  @override
  Future<Either<Failure, String>> call(UploadActivityImageParams params) {
    return repository.uploadActivityImage(params.activityId, params.imageFile);
  }
}

class UploadActivityImageParams extends Equatable {
  final int activityId;
  final File imageFile;

  const UploadActivityImageParams({
    required this.activityId,
    required this.imageFile,
  });

  @override
  List<Object> get props => [activityId, imageFile.path];
}
