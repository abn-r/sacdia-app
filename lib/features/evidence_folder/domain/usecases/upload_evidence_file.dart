import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/evidence_file.dart';
import '../repositories/evidence_folder_repository.dart';

class UploadEvidenceFileParams extends Equatable {
  final String clubSectionId;
  final String sectionId;
  final String filePath;
  final String fileName;
  final String mimeType;

  const UploadEvidenceFileParams({
    required this.clubSectionId,
    required this.sectionId,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
  });

  @override
  List<Object?> get props =>
      [clubSectionId, sectionId, filePath, fileName, mimeType];
}

/// Caso de uso: subir un archivo de evidencia a una sección.
class UploadEvidenceFile
    implements UseCase<EvidenceFile, UploadEvidenceFileParams> {
  final EvidenceFolderRepository _repository;

  UploadEvidenceFile(this._repository);

  @override
  Future<Either<Failure, EvidenceFile>> call(
      UploadEvidenceFileParams params) async {
    return _repository.uploadFile(
      clubSectionId: params.clubSectionId,
      sectionId: params.sectionId,
      filePath: params.filePath,
      fileName: params.fileName,
      mimeType: params.mimeType,
    );
  }
}
