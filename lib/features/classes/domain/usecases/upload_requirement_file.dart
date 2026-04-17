import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/requirement_evidence.dart';
import '../repositories/classes_repository.dart';

class UploadRequirementFileParams extends Equatable {
  final String userId;
  final int classId;
  final int requirementId;
  final String filePath;
  final String fileName;
  final String mimeType;
  final void Function(double)? onProgress;

  const UploadRequirementFileParams({
    required this.userId,
    required this.classId,
    required this.requirementId,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    this.onProgress,
  });

  @override
  List<Object?> get props =>
      [userId, classId, requirementId, filePath, fileName, mimeType];
}

/// Caso de uso: sube un archivo de evidencia a un requerimiento de clase.
class UploadRequirementFile
    implements UseCase<RequirementEvidence, UploadRequirementFileParams> {
  final ClassesRepository _repository;

  UploadRequirementFile(this._repository);

  @override
  Future<Either<Failure, RequirementEvidence>> call(
      UploadRequirementFileParams params) async {
    return _repository.uploadRequirementFile(
      userId: params.userId,
      classId: params.classId,
      requirementId: params.requirementId,
      filePath: params.filePath,
      fileName: params.fileName,
      mimeType: params.mimeType,
      onProgress: params.onProgress,
    );
  }
}
