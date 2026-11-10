import '../../domain/entities/service_credential.dart';
import '../../domain/entities/service_credential_review.dart';

/// Parseo tolerante de los contratos de constancias de servicio. Todo campo
/// opcional puede venir `null` o ausente y un enum desconocido no rompe nada.

Map<String, dynamic>? _map(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : null;

String? _text(Object? raw) {
  final value = raw?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

int? _int(Object? raw) {
  if (raw is num) return raw.toInt();
  if (raw == null) return null;
  return int.tryParse('$raw');
}

DateTime? _date(Object? raw) {
  final text = _text(raw);
  return text == null ? null : DateTime.tryParse(text);
}

/// `YYYY-MM-DD` sin zona horaria: la fecha del calendario que eligió la persona.
String formatApiDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
}

ServiceCredential serviceCredentialFromJson(Map<String, dynamic> json) =>
    ServiceCredential(
      id: json['credential_id']?.toString() ?? '',
      type: _text(json['type']) ?? kCounselorTrainingType,
      completedAt: _date(json['completed_at']),
      status: ServiceCredentialStatus.parse(json['status']),
      uploadStatus: ServiceCredentialUploadStatus.parse(json['upload_status']),
      decisionReason: _text(json['decision_reason']),
      reviewedAt: _date(json['reviewed_at']),
      expiresAt: _date(json['expires_at']),
      fileName: _text(json['file_name']),
      createdAt: _date(json['created_at']),
    );

/// `data.items` de `GET /users/me/service-credentials`.
List<ServiceCredential> serviceCredentialListFromData(Object? data) {
  final items = _map(data)?['items'];
  if (items is! List) return const [];
  return [
    for (final raw in items)
      if (_map(raw) != null) serviceCredentialFromJson(_map(raw)!),
  ];
}

/// Respuesta del `POST /users/me/service-credentials`.
class ServiceCredentialTicket {
  const ServiceCredentialTicket({
    required this.credential,
    required this.uploadUrl,
    required this.uploadMethod,
    required this.uploadHeaders,
    required this.expiresIn,
  });

  final ServiceCredential credential;
  final String uploadUrl;
  final String uploadMethod;
  final Map<String, String> uploadHeaders;
  final int expiresIn;

  factory ServiceCredentialTicket.fromJson(Map<String, dynamic> json) {
    final upload = _map(json['upload']) ?? const <String, dynamic>{};
    final headers = _map(upload['headers']) ?? const <String, dynamic>{};
    return ServiceCredentialTicket(
      credential: serviceCredentialFromJson(_map(json['credential']) ?? {}),
      uploadUrl: _text(upload['url']) ?? '',
      uploadMethod: (_text(upload['method']) ?? 'PUT').toUpperCase(),
      uploadHeaders: {
        for (final e in headers.entries)
          if (e.value != null) e.key: e.value.toString(),
      },
      expiresIn: _int(upload['expires_in']) ?? 0,
    );
  }
}

ReviewItem reviewItemFromJson(Map<String, dynamic> json) {
  final user = _map(json['user']) ?? const <String, dynamic>{};
  return ReviewItem(
    id: json['credential_id']?.toString() ?? '',
    person: ReviewPerson(
      userId: user['user_id']?.toString() ?? '',
      name: user['name']?.toString() ?? '',
      photoUrl: _text(user['photo_url']),
    ),
    clubName: _text(json['club_name']),
    completedAt: _date(json['completed_at']),
    status: ServiceCredentialStatus.parse(json['status']),
    createdAt: _date(json['created_at']),
    reviewedAt: _date(json['reviewed_at']),
    reviewerRole: _text(json['reviewer_role']),
  );
}

/// Cuerpo completo de `GET /service-credentials/review` (la paginación y los
/// conteos viven en `meta`, fuera de `data`).
ReviewPage reviewPageFromBody(Map<String, dynamic> body) {
  final data = body['data'];
  final rawItems = data is List ? data : _map(data)?['items'];
  final meta = _map(body['meta']) ?? const <String, dynamic>{};
  final counts = _map(meta['counts']) ?? const <String, dynamic>{};
  final items = [
    if (rawItems is List)
      for (final raw in rawItems)
        if (_map(raw) != null) reviewItemFromJson(_map(raw)!),
  ];
  return ReviewPage(
    items: items,
    page: _int(meta['page']) ?? 1,
    limit: _int(meta['limit']) ?? 20,
    total: _int(meta['total']) ?? items.length,
    counts: ReviewCounts(
      pending: _int(counts['pending']) ?? 0,
      approved: _int(counts['approved']) ?? 0,
      rejected: _int(counts['rejected']) ?? 0,
    ),
  );
}

/// `data` de `GET /service-credentials/review/:id`.
ReviewDetail reviewDetailFromData(Map<String, dynamic> data) => ReviewDetail(
      item: reviewItemFromJson(data),
      fileUrl: _text(data['file_url']),
      mimeType: _text(data['mime_type']),
      decisionReason: _text(data['decision_reason']),
      expiresAt: _date(data['expires_at']),
    );
