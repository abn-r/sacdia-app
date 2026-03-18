import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/member_insurance.dart';
import '../repositories/insurance_repository.dart';

/// Parámetros para crear un nuevo registro de seguro.
class CreateInsuranceParams extends Equatable {
  final String memberId;
  final InsuranceType insuranceType;
  final DateTime startDate;
  final DateTime endDate;
  final String? policyNumber;
  final String? providerName;
  final double? coverageAmount;
  final String? evidenceFilePath;
  final String? evidenceFileName;
  final String? evidenceMimeType;

  const CreateInsuranceParams({
    required this.memberId,
    required this.insuranceType,
    required this.startDate,
    required this.endDate,
    this.policyNumber,
    this.providerName,
    this.coverageAmount,
    this.evidenceFilePath,
    this.evidenceFileName,
    this.evidenceMimeType,
  });

  @override
  List<Object?> get props => [
        memberId,
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

/// Caso de uso: registra un nuevo seguro para un miembro.
class CreateInsurance {
  final InsuranceRepository _repository;

  const CreateInsurance(this._repository);

  Future<Either<Failure, MemberInsurance>> call(
      CreateInsuranceParams params) {
    return _repository.createInsurance(
      memberId: params.memberId,
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
