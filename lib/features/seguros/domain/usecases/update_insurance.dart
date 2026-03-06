import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/member_insurance.dart';
import '../repositories/seguros_repository.dart';

/// Parámetros para actualizar un registro de seguro existente.
class UpdateInsuranceParams extends Equatable {
  final int insuranceId;
  final InsuranceType? insuranceType;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? policyNumber;
  final String? providerName;
  final double? coverageAmount;
  final String? evidenceFilePath;
  final String? evidenceFileName;
  final String? evidenceMimeType;

  const UpdateInsuranceParams({
    required this.insuranceId,
    this.insuranceType,
    this.startDate,
    this.endDate,
    this.policyNumber,
    this.providerName,
    this.coverageAmount,
    this.evidenceFilePath,
    this.evidenceFileName,
    this.evidenceMimeType,
  });

  @override
  List<Object?> get props => [
        insuranceId,
        insuranceType,
        startDate,
        endDate,
        policyNumber,
        providerName,
        coverageAmount,
        evidenceFilePath,
        evidenceFileName,
        evidenceMimeType,
      ];
}

/// Caso de uso: actualiza un registro de seguro existente.
class UpdateInsurance {
  final SegurosRepository _repository;

  const UpdateInsurance(this._repository);

  Future<Either<Failure, MemberInsurance>> call(
      UpdateInsuranceParams params) {
    return _repository.updateInsurance(
      insuranceId: params.insuranceId,
      insuranceType: params.insuranceType,
      startDate: params.startDate,
      endDate: params.endDate,
      policyNumber: params.policyNumber,
      providerName: params.providerName,
      coverageAmount: params.coverageAmount,
      evidenceFilePath: params.evidenceFilePath,
      evidenceFileName: params.evidenceFileName,
      evidenceMimeType: params.evidenceMimeType,
    );
  }
}
