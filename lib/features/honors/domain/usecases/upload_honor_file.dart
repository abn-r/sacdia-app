import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/honors_repository.dart';

/// Caso de uso para subir un archivo de evidencia general de una especialidad.
class UploadHonorFile implements UseCase<void, UploadHonorFileParams> {
  final HonorsRepository repository;

  UploadHonorFile(this.repository);

  @override
  Future<Either<Failure, void>> call(UploadHonorFileParams params) {
    return repository.uploadHonorFile(
      userId: params.userId,
      honorId: params.honorId,
      file: params.file,
      fileName: params.fileName,
    );
  }
}

class UploadHonorFileParams extends Equatable {
  final String userId;
  final int honorId;
  final File file;
  final String fileName;

  const UploadHonorFileParams({
    required this.userId,
    required this.honorId,
    required this.file,
    required this.fileName,
  });

  @override
  List<Object> get props => [userId, honorId, file.path, fileName];
}
