import 'package:equatable/equatable.dart';

/// Tipo de dispositivo reportado por el backend.
enum SessionDeviceType { ios, android, web, unknown }

/// Representa una sesión activa del usuario en la plataforma.
///
/// Refleja exactamente la respuesta de GET /auth/sessions.
class ActiveSession extends Equatable {
  final String sessionId;
  final SessionDeviceType deviceType;
  final String? deviceName;
  final String? ipAddress;
  final String? location;
  final String? userAgent;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool isCurrent;
  final DateTime expiresAt;

  const ActiveSession({
    required this.sessionId,
    required this.deviceType,
    this.deviceName,
    this.ipAddress,
    this.location,
    this.userAgent,
    required this.createdAt,
    required this.lastActiveAt,
    required this.isCurrent,
    required this.expiresAt,
  });

  /// Nombre para mostrar: deviceName o fallback "Dispositivo desconocido".
  String get displayName =>
      deviceName?.isNotEmpty == true ? deviceName! : 'Dispositivo desconocido';

  @override
  List<Object?> get props => [
        sessionId,
        deviceType,
        deviceName,
        ipAddress,
        location,
        userAgent,
        createdAt,
        lastActiveAt,
        isCurrent,
        expiresAt,
      ];
}

/// Returns [sessions] with the current session first. The backend orders by
/// creation date, so the current one can land anywhere; the rest keep their
/// order.
List<ActiveSession> currentSessionFirst(List<ActiveSession> sessions) => [
      ...sessions.where((s) => s.isCurrent),
      ...sessions.where((s) => !s.isCurrent),
    ];
