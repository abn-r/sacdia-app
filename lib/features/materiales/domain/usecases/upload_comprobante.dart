import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/comprobante.dart';
import '../repositories/materiales_repository.dart';

class UploadComprobanteParams extends Equatable {
  final String folioOrId;
  final File file;
  final int montoCentavos;
  final String refBancariaDeclarada;
  final DateTime fechaPago;
  final void Function(double)? onProgress;

  const UploadComprobanteParams({
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
class UploadComprobante
    implements UseCase<Comprobante, UploadComprobanteParams> {
  UploadComprobante(this._repo);
  final MaterialesRepository _repo;

  @override
  Future<Either<Failure, Comprobante>> call(
          UploadComprobanteParams params) =>
      _repo.uploadComprobante(
        folioOrId: params.folioOrId,
        file: params.file,
        montoCentavos: params.montoCentavos,
        refBancariaDeclarada: params.refBancariaDeclarada,
        fechaPago: params.fechaPago,
        onProgress: params.onProgress,
      );
}
