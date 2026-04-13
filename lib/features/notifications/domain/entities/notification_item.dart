import 'package:equatable/equatable.dart';

/// Tipos de notificación según el campo [target_type] del backend.
enum NotificationTargetType {
  direct,
  broadcast,
  section,
  unknown;

  static NotificationTargetType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'direct':
        return NotificationTargetType.direct;
      case 'broadcast':
        return NotificationTargetType.broadcast;
      case 'section':
        return NotificationTargetType.section;
      default:
        return NotificationTargetType.unknown;
    }
  }
}

/// Entidad de dominio que representa una notificación del historial.
///
/// Corresponde a un registro de [NotificationLog] del backend
/// (GET /notifications/history).
class NotificationItem extends Equatable {
  final int logId;
  final String title;
  final String body;
  final String type;
  final NotificationTargetType targetType;
  final String? targetId;
  final String sentBy;
  final int tokensSent;
  final int tokensFailed;
  final DateTime createdAt;

  /// Nombre completo del remitente, resuelto desde el objeto [users] del backend.
  final String? senderName;

  const NotificationItem({
    required this.logId,
    required this.title,
    required this.body,
    required this.type,
    required this.targetType,
    this.targetId,
    required this.sentBy,
    required this.tokensSent,
    required this.tokensFailed,
    required this.createdAt,
    this.senderName,
  });

  @override
  List<Object?> get props => [
        logId,
        title,
        body,
        type,
        targetType,
        targetId,
        sentBy,
        tokensSent,
        tokensFailed,
        createdAt,
        senderName,
      ];
}
