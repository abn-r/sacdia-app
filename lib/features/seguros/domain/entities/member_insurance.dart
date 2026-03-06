import 'package:equatable/equatable.dart';

/// Estado del seguro de un miembro.
enum InsuranceStatus {
  asegurado,
  vencido,
  sinSeguro;

  String get label {
    switch (this) {
      case InsuranceStatus.asegurado:
        return 'Asegurado';
      case InsuranceStatus.vencido:
        return 'Vencido';
      case InsuranceStatus.sinSeguro:
        return 'Sin seguro';
    }
  }

  String get shortLabel {
    switch (this) {
      case InsuranceStatus.asegurado:
        return 'Asegurado';
      case InsuranceStatus.vencido:
        return 'Vencido';
      case InsuranceStatus.sinSeguro:
        return 'Sin seguro';
    }
  }
}

/// Tipo de seguro (mapeado desde insurance_type_enum del backend).
enum InsuranceType {
  generalActivities,
  camporee,
  highRisk;

  String get label {
    switch (this) {
      case InsuranceType.generalActivities:
        return 'Actividades Generales';
      case InsuranceType.camporee:
        return 'Camporee';
      case InsuranceType.highRisk:
        return 'Alto Riesgo';
    }
  }

  String get apiValue {
    switch (this) {
      case InsuranceType.generalActivities:
        return 'GENERAL_ACTIVITIES';
      case InsuranceType.camporee:
        return 'CAMPOREE';
      case InsuranceType.highRisk:
        return 'HIGH_RISK';
    }
  }
}

/// Entidad que representa la información de seguro de un miembro del club.
///
/// Combina datos del miembro (de club_members) con datos de su seguro
/// (de member_insurances). Un miembro puede tener [status] == [InsuranceStatus.sinSeguro]
/// si no tiene ningún registro de seguro activo.
class MemberInsurance extends Equatable {
  /// ID único del registro de seguro en el backend (null si sin seguro).
  final int? insuranceId;

  /// ID del usuario miembro (UUID del sistema de auth).
  final String memberId;

  /// Nombre completo del miembro.
  final String memberName;

  /// URL de la foto/avatar del miembro.
  final String? memberPhotoUrl;

  /// Clase progresiva actual del miembro (p.e. "Explorador").
  final String? memberClass;

  /// Estado calculado del seguro.
  final InsuranceStatus status;

  // ── Detalles del seguro (null si sinSeguro) ──────────────────────────────

  /// Tipo de seguro registrado.
  final InsuranceType? insuranceType;

  /// Número de póliza / folio.
  final String? policyNumber;

  /// Nombre de la aseguradora / proveedor.
  final String? providerName;

  /// Fecha de inicio de la cobertura.
  final DateTime? startDate;

  /// Fecha de vencimiento de la cobertura.
  final DateTime? endDate;

  /// Monto de la cobertura / prima pagada.
  final double? coverageAmount;

  /// URL del archivo de evidencia de pago (imagen o PDF).
  final String? evidenceFileUrl;

  /// Nombre del archivo de evidencia.
  final String? evidenceFileName;

  // ── Auditoría ────────────────────────────────────────────────────────────

  final String? registeredByName;
  final DateTime? registeredAt;
  final String? modifiedByName;
  final DateTime? modifiedAt;

  const MemberInsurance({
    this.insuranceId,
    required this.memberId,
    required this.memberName,
    this.memberPhotoUrl,
    this.memberClass,
    required this.status,
    this.insuranceType,
    this.policyNumber,
    this.providerName,
    this.startDate,
    this.endDate,
    this.coverageAmount,
    this.evidenceFileUrl,
    this.evidenceFileName,
    this.registeredByName,
    this.registeredAt,
    this.modifiedByName,
    this.modifiedAt,
  });

  // ── Computed helpers ─────────────────────────────────────────────────────

  /// Días hasta el vencimiento (positivo = vigente, negativo = vencido).
  /// Retorna null si no hay fecha de vencimiento.
  int? get daysUntilExpiry {
    if (endDate == null) return null;
    return endDate!.difference(DateTime.now()).inDays;
  }

  /// true si el seguro vence en los próximos [days] días.
  bool isExpiringSoon({int days = 30}) {
    final diff = daysUntilExpiry;
    return diff != null && diff >= 0 && diff <= days;
  }

  @override
  List<Object?> get props => [
        insuranceId,
        memberId,
        memberName,
        memberPhotoUrl,
        memberClass,
        status,
        insuranceType,
        policyNumber,
        providerName,
        startDate,
        endDate,
        coverageAmount,
        evidenceFileUrl,
        evidenceFileName,
        registeredByName,
        registeredAt,
        modifiedByName,
        modifiedAt,
      ];
}
