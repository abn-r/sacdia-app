import '../../../../core/config/device_pair_link.dart';
import '../../domain/entities/linked_device.dart';

/// Parseo tolerante de los contratos de dispositivos vinculados (`data` ya sin
/// el envelope `{status, data}`).
abstract final class LinkedDeviceJson {
  static DateTime? _date(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

  static String? _string(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString();
    return value.isEmpty ? null : value;
  }

  static int? _int(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// `{devices:[...], limits:{max_devices}}`.
  static LinkedDevices list(Map<String, dynamic> json) {
    final raw = json['devices'];
    final limits = json['limits'];
    final max = limits is Map ? _int(limits['max_devices']) : null;
    return LinkedDevices(
      devices: [
        if (raw is List)
          for (final item in raw)
            if (item is Map) _device(Map<String, dynamic>.from(item)),
      ],
      // Un tope ausente o absurdo cae al acordado (2): el lado seguro es el
      // más bajo.
      maxDevices: max != null && max > 0 ? max : kDefaultMaxLinkedDevices,
    );
  }

  static LinkedDevice _device(Map<String, dynamic> json) {
    final status = _string(json['status']);
    final revokedAt = _date(json['revoked_at']);
    return LinkedDevice(
      id: (json['linked_device_id'] ?? json['id']).toString(),
      label: _string(json['label']) ?? '—',
      platform: _string(json['platform']),
      appVersion: _string(json['app_version']),
      pairedAt: _date(json['paired_at']),
      pairedByDisplayName: _string(json['paired_by_display_name']),
      lastSeenAt: _date(json['last_seen_at']),
      absoluteExpiresAt: _date(json['absolute_expires_at']),
      // El estado también puede venir como `status: revoked` sin fecha.
      revokedAt: revokedAt ?? (status == 'revoked' ? DateTime.now() : null),
    );
  }

  /// `201 {pairing_token, qr_payload, expires_at, expires_in}`.
  static DevicePairingToken pairingToken(
    Map<String, dynamic> json, {
    required DateTime now,
  }) {
    final token = _string(json['pairing_token']);
    if (token == null) {
      throw const FormatException('pairing_token missing');
    }
    final expiresIn = _int(json['expires_in']);
    final expiresAt = _date(json['expires_at']) ??
        now.add(Duration(seconds: expiresIn ?? 600));
    // El QR solo lleva un enlace de vinculación que contenga ESTE token. Si el
    // servidor no manda el payload (o manda otra cosa) se arma con el esquema
    // acordado: el teléfono del niño acepta `c` y `t`.
    final payload = _string(json['qr_payload']);
    final payloadUri = payload == null ? null : Uri.tryParse(payload);
    final qrPayload = payload != null &&
            payloadUri != null &&
            pairingTokenFromUri(payloadUri) == token
        ? payload
        : 'sacdia://pair?c=$token';
    return DevicePairingToken(
      token: token,
      qrPayload: qrPayload,
      expiresAt: expiresAt,
      issuedAt: now,
    );
  }

  /// `200 {linked_device_id, revoked_at, revoked_reason}`.
  static RevokedDevice revoked(Map<String, dynamic> json) => RevokedDevice(
        linkedDeviceId: json['linked_device_id'].toString(),
        revokedAt: _date(json['revoked_at']),
      );
}
