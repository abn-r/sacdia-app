import '../../../auth/domain/entities/principal_info.dart';
import '../../domain/entities/teen_supervision.dart';

/// Parseo tolerante de los contratos del adolescente (`data` ya sin el envelope
/// `{status, data}`). Un campo ausente nunca debe tumbar la pantalla y los
/// datos de contacto jamás se leen.
abstract final class TeenJson {
  static DateTime? _date(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

  static String? _string(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString();
    return value.isEmpty ? null : value;
  }

  static TeenGuardian _guardian(Map<String, dynamic> json) {
    final consent = json['consent_status'];
    return TeenGuardian(
      guardianshipId: _string(json['guardianship_id']),
      displayName: _string(json['display_name']) ?? '—',
      relationshipTypeName: _string(json['relationship_type_name']),
      // Solo un `verified` explícito cuenta: el valor por defecto es el lado
      // seguro (sin poderes).
      verified: consent == 'verified' || json['verified'] == true,
    );
  }

  static TeenSupervision supervision(Map<String, dynamic> json) {
    final guardians = json['guardians'];
    final open = json['open_link_code'];
    final openExpires = open is Map ? _date(open['expires_at']) : null;
    return TeenSupervision(
      status: SupervisionStatus.parse(json['status']),
      pendingSince: _date(json['pending_since']),
      guardians: guardians is List
          ? guardians
              .whereType<Map>()
              .map((g) => _guardian(Map<String, dynamic>.from(g)))
              .toList(growable: false)
          : const [],
      openLinkCode:
          openExpires == null ? null : OpenTeenLinkCode(expiresAt: openExpires),
      summaryVisibleToGuardians: json['summary_visible_to_guardians'] != false,
    );
  }

  static TeenLinkCode linkCode(Map<String, dynamic> json) {
    return TeenLinkCode(
      code: json['code'].toString(),
      // El TTL decidido es de 72 h: si el servidor no manda la fecha se asume.
      expiresAt: _date(json['expires_at']) ??
          DateTime.now().add(const Duration(hours: 72)),
    );
  }
}
