import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/receipt.dart';
import '../repositories/materials_repository.dart';

class UploadReceiptParams extends Equatable {
  final String folioOrId;
  final File file;
  final int montoCentavos;
  final String refBancariaDeclarada;
  final DateTime fechaPago;
  final void Function(double)? onProgress;

  const UploadReceiptParams({
    required this.folioOrId,
    required this.file,
    required this.montoCentavos,
    required this.refBancariaDeclarada,
    required this.fechaPago,
    this.onProgress,
  });

  @override
  List<Object?> get props =>
      [folioOrId, file.path, montoCentavos, refBancariaDeclarada, fechaPago];
}

/// Caso de uso: subir un comprobante de pago para una orden aprobada.
class UploadReceipt implements UseCase<Receipt, UploadReceiptParams> {
  UploadReceipt(this._repo);
  final MaterialsRepository _repo;

  @override
  Future<Either<Failure, Receipt>> call(UploadReceiptParams params) =>
      _repo.uploadReceipt(
        folioOrId: params.folioOrId,
        file: params.file,
        montoCentavos: params.montoCentavos,
        refBancariaDeclarada: params.refBancariaDeclarada,
        fechaPago: params.fechaPago,
        onProgress: params.onProgress,
      );
}
