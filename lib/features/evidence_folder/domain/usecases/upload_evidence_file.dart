import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/evidence_file.dart';
import '../repositories/evidence_folder_repository.dart';

class UploadEvidenceFileParams extends Equatable {
  final String folderId;
  final String sectionId;
  final String filePath;
  final String fileName;
  final String mimeType;
  final String? notes;
  final void Function(double)? onProgress;

  const UploadEvidenceFileParams({
    required this.folderId,
    required this.sectionId,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    this.notes,
    this.onProgress,
  });

  @override
  List<Object?> get props =>
      [folderId, sectionId, filePath, fileName, mimeType, notes];
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
      folderId: params.folderId,
      sectionId: params.sectionId,
      filePath: params.filePath,
      fileName: params.fileName,
      mimeType: params.mimeType,
      notes: params.notes,
      onProgress: params.onProgress,
    );
  }
}
