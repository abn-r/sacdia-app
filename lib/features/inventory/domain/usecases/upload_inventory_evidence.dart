import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

class UploadInventoryEvidenceParams extends Equatable {
  final int itemId;
  final String filePath;
  final String fileName;
  final String mimeType;

  const UploadInventoryEvidenceParams({
    required this.itemId,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
  });

  @override
  List<Object?> get props => [itemId, filePath, fileName, mimeType];
}

class UploadInventoryEvidence {
  final InventoryRepository repository;

  UploadInventoryEvidence(this.repository);

  Future<Either<Failure, InventoryEvidence>> call(
    UploadInventoryEvidenceParams params,
  ) {
    return repository.uploadEvidence(
      itemId: params.itemId,
      filePath: params.filePath,
      fileName: params.fileName,
      mimeType: params.mimeType,
    );
  }
}
