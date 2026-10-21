import '../../../members/data/models/join_request_model.dart';
import '../../domain/entities/consent_pending_queue.dart';

/// Respuesta de `GET /coordination/me/consent-pending` (el `data`, sin el sobre
/// `{ status, data }`).
class ConsentPendingPageModel extends ConsentPendingPage {
  const ConsentPendingPageModel({
    super.items,
    super.total,
    super.limit,
    super.offset,
    super.bySection,
  });

  factory ConsentPendingPageModel.fromJson(Map<String, dynamic> json) {
    return ConsentPendingPageModel(
      items: _maps(json['items']).map(_item).toList(growable: false),
      total: _int(json['total']),
      limit: _int(json['limit']),
      offset: _int(json['offset']),
      bySection:
          _maps(json['by_section']).map(_section).toList(growable: false),
    );
  }

  /// El ítem es una solicitud de ingreso (con su bloque `consent`) más la
  /// sección. `JoinRequestModel` arma el id `<sección>/membership-requests/<id>`
  /// que usa la verificación.
  static ConsentPendingItem _item(Map<String, dynamic> json) =>
      ConsentPendingItem(
        request: JoinRequestModel.fromJson(json),
        clubSectionId: _intOrNull(json['club_section_id']),
        clubName: _string(json['club_name']),
        clubTypeName: _string(json['club_type_name']),
        districtName: _string(json['district_name']),
        formUploadedAt: json['consent_form_uploaded_at'] == null
            ? null
            : DateTime.tryParse(json['consent_form_uploaded_at'].toString()),
      );

  static ConsentPendingSection _section(Map<String, dynamic> json) =>
      ConsentPendingSection(
        clubSectionId: _int(json['club_section_id']),
        clubName: _string(json['club_name']),
        clubTypeName: _string(json['club_type_name']),
        districtName: _string(json['district_name']),
        pendingConsentCount: _int(json['pending_consent_count']),
      );

  static Iterable<Map<String, dynamic>> _maps(Object? raw) => raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e))
      : const [];

  static int? _intOrNull(Object? raw) =>
      raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');

  static int _int(Object? raw) => _intOrNull(raw) ?? 0;

  static String? _string(Object? raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }
}
