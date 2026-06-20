import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/transaction.dart';
import '../repositories/finances_repository.dart';

class UploadFinanceEvidenceParams extends Equatable {
  final int financeId;
  final String filePath;
  final String fileName;
  final String mimeType;

  const UploadFinanceEvidenceParams({
    required this.financeId,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
  });

  @override
  List<Object?> get props => [financeId, filePath, fileName, mimeType];
}

class UploadFinanceEvidence {
  final FinancesRepository repository;

  UploadFinanceEvidence(this.repository);

  Future<Either<Failure, FinanceEvidence>> call(
    UploadFinanceEvidenceParams params,
  ) {
    return repository.uploadEvidence(
      financeId: params.financeId,
      filePath: params.filePath,
      fileName: params.fileName,
      mimeType: params.mimeType,
    );
  }
}
