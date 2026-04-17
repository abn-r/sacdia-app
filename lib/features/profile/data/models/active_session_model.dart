import '../../domain/entities/active_session.dart';

/// Modelo de datos que mapea la respuesta JSON de GET /auth/sessions.
class ActiveSessionModel extends ActiveSession {
  const ActiveSessionModel({
    required super.sessionId,
    required super.deviceType,
    super.deviceName,
    super.ipAddress,
    super.location,
    super.userAgent,
    required super.createdAt,
    required super.lastActiveAt,
    required super.isCurrent,
    required super.expiresAt,
  });

  factory ActiveSessionModel.fromJson(Map<String, dynamic> json) {
    return ActiveSessionModel(
      sessionId: json['session_id'] as String,
      deviceType: _parseDeviceType(json['device_type'] as String?),
      deviceName: json['device_name'] as String?,
      ipAddress: json['ip_address'] as String?,
      location: json['location'] as String?,
      userAgent: json['user_agent'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastActiveAt: DateTime.parse(json['last_active_at'] as String),
      isCurrent: json['is_current'] as bool? ?? false,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'device_type': _deviceTypeToString(deviceType),
        'device_name': deviceName,
        'ip_address': ipAddress,
        'location': location,
        'user_agent': userAgent,
        'created_at': createdAt.toIso8601String(),
        'last_active_at': lastActiveAt.toIso8601String(),
        'is_current': isCurrent,
        'expires_at': expiresAt.toIso8601String(),
      };

  static SessionDeviceType _parseDeviceType(String? raw) {
    switch (raw) {
      case 'ios':
        return SessionDeviceType.ios;
      case 'android':
        return SessionDeviceType.android;
      case 'web':
        return SessionDeviceType.web;
      default:
        return SessionDeviceType.unknown;
    }
  }

  static String _deviceTypeToString(SessionDeviceType type) {
    switch (type) {
      case SessionDeviceType.ios:
        return 'ios';
      case SessionDeviceType.android:
        return 'android';
      case SessionDeviceType.web:
        return 'web';
      case SessionDeviceType.unknown:
        return 'unknown';
    }
  }
}
