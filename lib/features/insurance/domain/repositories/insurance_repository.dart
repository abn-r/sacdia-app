import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/member_insurance.dart';

/// Contrato de acceso a datos del módulo de seguros del club.
abstract class InsuranceRepository {
  /// Devuelve todos los miembros del club con su estado de seguro.
  ///
  /// La lista incluye miembros asegurados, con seguro vencido y sin seguro,
  /// permitiendo a la pantalla principal mostrar la cobertura completa.
  Future<Either<Failure, List<MemberInsurance>>> getMembersInsurance({
    required int clubId,
    required int sectionId,
  });

  /// Obtiene el detalle del seguro de un miembro específico.
  Future<Either<Failure, MemberInsurance>> getMemberInsuranceDetail({
    required String memberId,
  });

  /// Registra un nuevo seguro para un miembro.
  Future<Either<Failure, MemberInsurance>> createInsurance({
    required String memberId,
    required InsuranceType insuranceType,
    required DateTime startDate,
    required DateTime endDate,
    String? policyNumber,
    String? providerName,
    double? coverageAmount,
    String? evidenceFilePath,
    String? evidenceFileName,
    String? evidenceMimeType,
  });

  /// Actualiza un registro de seguro existente.
  Future<Either<Failure, MemberInsurance>> updateInsurance({
    required int insuranceId,
    InsuranceType? insuranceType,
    DateTime? startDate,
    DateTime? endDate,
    String? policyNumber,
    String? providerName,
    double? coverageAmount,
    String? evidenceFilePath,
    String? evidenceFileName,
    String? evidenceMimeType,
  });

  /// Obtiene seguros que vencen en los próximos [days] días.
  Future<Either<Failure, List<MemberInsurance>>> getExpiringInsurance({
    required int days,
  });

}
