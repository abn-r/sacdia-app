import '../../domain/entities/member_insurance.dart';

/// Modelo de datos para la respuesta de la API de seguros.
///
/// La API devuelve la lista de miembros del club con su estado de seguro.
/// El backend combina datos de `club_members` / `users` con `member_insurances`.
///
/// Respuesta esperada de GET /clubs/:clubId/instances/:type/:instanceId/members/insurance:
/// ```json
/// [
///   {
///     "user_id": "uuid",
///     "name": "Juan",
///     "paternal_last_name": "García",
///     "maternal_last_name": "López",
///     "user_image": "https://...",
///     "current_class": { "name": "Explorador" },
///     "insurance": {           // null si no tiene seguro
///       "insurance_id": 1,
///       "insurance_type": "GENERAL_ACTIVITIES",
///       "policy_number": "POL-001",
///       "provider": "Seguros SACDIA",
///       "start_date": "2025-01-01",
///       "end_date": "2025-12-31",
///       "coverage_amount": 500.00,
///       "active": true,
///       "evidence_file_url": "https://...",
///       "evidence_file_name": "comprobante.pdf",
///       "created_at": "2025-01-10T12:00:00Z",
///       "modified_at": "2025-01-10T12:00:00Z",
///       "created_by_name": "Director Juan",
///       "modified_by_name": null
///     }
///   }
/// ]
/// ```
class MemberInsuranceModel extends MemberInsurance {
  const MemberInsuranceModel({
    super.insuranceId,
    required super.memberId,
    required super.memberName,
    super.memberPhotoUrl,
    super.memberClass,
    required super.status,
    super.insuranceType,
    super.policyNumber,
    super.providerName,
    super.startDate,
    super.endDate,
    super.coverageAmount,
    super.evidenceFileUrl,
    super.evidenceFileName,
    super.registeredByName,
    super.registeredAt,
    super.modifiedByName,
    super.modifiedAt,
  });

  // ── Factory desde respuesta compuesta (miembro + seguro) ──────────────────

  factory MemberInsuranceModel.fromJson(Map<String, dynamic> json) {
    // Datos del usuario — pueden venir planos o bajo 'user'
    final user = json['user'] as Map<String, dynamic>? ?? json;

    final userId =
        (user['user_id'] ?? user['id'] ?? json['user_id'] ?? '').toString();

    // Nombre completo
    final name = (user['name'] ?? '').toString();
    final paternal = (user['paternal_last_name'] ?? user['p_lastname'] ?? '').toString();
    final maternal = (user['maternal_last_name'] ?? user['m_lastname'] ?? '').toString();
    final fullName = [name, paternal, maternal]
        .where((s) => s.isNotEmpty)
        .join(' ');

    // Avatar
    final avatar =
        (user['user_image'] ?? user['avatar'] ?? json['user_image'])?.toString();

    // Clase progresiva
    final classData =
        json['current_class'] as Map<String, dynamic>? ??
        user['current_class'] as Map<String, dynamic>?;
    final memberClass = classData?['name']?.toString();

    // Datos del seguro (puede ser null)
    final insuranceJson = json['insurance'] as Map<String, dynamic>?;

    if (insuranceJson == null || insuranceJson.isEmpty) {
      // Sin seguro registrado
      return MemberInsuranceModel(
        insuranceId: null,
        memberId: userId,
        memberName: fullName.isNotEmpty ? fullName : 'Sin nombre',
        memberPhotoUrl: avatar,
        memberClass: memberClass,
        status: InsuranceStatus.sinSeguro,
      );
    }

    // Parsear fechas del seguro
    final startDate = _parseDate(insuranceJson['start_date']);
    final endDate = _parseDate(insuranceJson['end_date']);

    // Calcular estado: vencido si end_date < hoy
    final now = DateTime.now();
    InsuranceStatus status;
    if (endDate != null && endDate.isBefore(DateTime(now.year, now.month, now.day))) {
      status = InsuranceStatus.vencido;
    } else {
      status = InsuranceStatus.asegurado;
    }

    return MemberInsuranceModel(
      insuranceId: _parseInt(insuranceJson['insurance_id'] ?? insuranceJson['id']),
      memberId: userId,
      memberName: fullName.isNotEmpty ? fullName : 'Sin nombre',
      memberPhotoUrl: avatar,
      memberClass: memberClass,
      status: status,
      insuranceType: _parseType(insuranceJson['insurance_type']?.toString()),
      policyNumber: insuranceJson['policy_number']?.toString(),
      providerName: insuranceJson['provider']?.toString() ??
          insuranceJson['provider_name']?.toString(),
      startDate: startDate,
      endDate: endDate,
      coverageAmount: insuranceJson['coverage_amount'] != null
          ? _parseDouble(insuranceJson['coverage_amount'])
          : null,
      evidenceFileUrl: insuranceJson['evidence_file_url']?.toString(),
      evidenceFileName: insuranceJson['evidence_file_name']?.toString(),
      registeredByName: insuranceJson['created_by_name']?.toString(),
      registeredAt: _parseDate(insuranceJson['created_at']),
      modifiedByName: insuranceJson['modified_by_name']?.toString(),
      modifiedAt: insuranceJson['modified_at'] != null
          ? _parseDate(insuranceJson['modified_at'])
          : null,
    );
  }

  // ── Factory desde respuesta directa del detalle de seguro ─────────────────

  factory MemberInsuranceModel.fromDetailJson(Map<String, dynamic> json) {
    // El detalle incluye el user anidado y el seguro en el mismo nivel
    final user = json['user'] as Map<String, dynamic>? ?? {};
    final insurance = json['insurance'] as Map<String, dynamic>? ?? json;

    final name = (user['name'] ?? '').toString();
    final paternal = (user['paternal_last_name'] ?? '').toString();
    final maternal = (user['maternal_last_name'] ?? '').toString();
    final fullName = [name, paternal, maternal]
        .where((s) => s.isNotEmpty)
        .join(' ');

    final startDate = _parseDate(insurance['start_date']);
    final endDate = _parseDate(insurance['end_date']);
    final now = DateTime.now();

    InsuranceStatus status;
    if (endDate == null) {
      status = InsuranceStatus.sinSeguro;
    } else if (endDate.isBefore(DateTime(now.year, now.month, now.day))) {
      status = InsuranceStatus.vencido;
    } else {
      status = InsuranceStatus.asegurado;
    }

    return MemberInsuranceModel(
      insuranceId: _parseInt(insurance['insurance_id'] ?? insurance['id']),
      memberId: (user['user_id'] ?? user['id'] ?? json['user_id'] ?? '').toString(),
      memberName: fullName.isNotEmpty ? fullName : 'Sin nombre',
      memberPhotoUrl: (user['user_image'] ?? user['avatar'])?.toString(),
      memberClass: (json['current_class'] as Map<String, dynamic>?)?['name']?.toString(),
      status: status,
      insuranceType: _parseType(insurance['insurance_type']?.toString()),
      policyNumber: insurance['policy_number']?.toString(),
      providerName: insurance['provider']?.toString() ??
          insurance['provider_name']?.toString(),
      startDate: startDate,
      endDate: endDate,
      coverageAmount: insurance['coverage_amount'] != null
          ? _parseDouble(insurance['coverage_amount'])
          : null,
      evidenceFileUrl: insurance['evidence_file_url']?.toString(),
      evidenceFileName: insurance['evidence_file_name']?.toString(),
      registeredByName: insurance['created_by_name']?.toString(),
      registeredAt: _parseDate(insurance['created_at']),
      modifiedByName: insurance['modified_by_name']?.toString(),
      modifiedAt: insurance['modified_at'] != null
          ? _parseDate(insurance['modified_at'])
          : null,
    );
  }

  // ── Helpers estáticos ─────────────────────────────────────────────────────

  static InsuranceType _parseType(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'CAMPOREE':
        return InsuranceType.camporee;
      case 'HIGH_RISK':
        return InsuranceType.highRisk;
      case 'GENERAL_ACTIVITIES':
      default:
        return InsuranceType.generalActivities;
    }
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double _parseDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  MemberInsurance toEntity() => MemberInsurance(
        insuranceId: insuranceId,
        memberId: memberId,
        memberName: memberName,
        memberPhotoUrl: memberPhotoUrl,
        memberClass: memberClass,
        status: status,
        insuranceType: insuranceType,
        policyNumber: policyNumber,
        providerName: providerName,
        startDate: startDate,
        endDate: endDate,
        coverageAmount: coverageAmount,
        evidenceFileUrl: evidenceFileUrl,
        evidenceFileName: evidenceFileName,
        registeredByName: registeredByName,
        registeredAt: registeredAt,
        modifiedByName: modifiedByName,
        modifiedAt: modifiedAt,
      );
}
