import 'package:equatable/equatable.dart';

/// Tipos de notificación según el campo [target_type] del backend.
///
/// Valores reales enviados por el backend (notification_logs.target_type):
/// - 'user'          → [direct]       (notificación directa a un usuario)
/// - 'all'           → [broadcast]    (a todos los usuarios)
/// - 'club_section'  → [club]         (a todos los miembros de una sección)
/// - 'section_role'  → [sectionRole]  (a usuarios con un rol en una sección)
/// - 'global_role'   → [globalRole]   (a usuarios con un rol global)
enum NotificationTargetType {
  direct,
  broadcast,
  club,
  sectionRole,
  globalRole,
  unknown;

  static NotificationTargetType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'user':
        return NotificationTargetType.direct;
      case 'all':
        return NotificationTargetType.broadcast;
      case 'club_section':
        return NotificationTargetType.club;
      case 'section_role':
        return NotificationTargetType.sectionRole;
      case 'global_role':
        return NotificationTargetType.globalRole;
      default:
        return NotificationTargetType.unknown;
    }
  }
}

/// Entidad de dominio que representa una notificación del historial.
///
/// Para usuarios regulares, corresponde a un registro de
/// [notification_deliveries] JOIN [notification_logs] del backend
/// (GET /notifications/history).
///
/// Para admins, corresponde a un registro de [notification_logs].
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

  // ── Campos de delivery (sólo presentes para usuarios regulares) ───────────

  /// UUID del registro en notification_deliveries.
  /// Null para admins (que leen notification_logs directamente).
  final String? deliveryId;

  /// true si read_at no es null (la notificación fue leída).
  final bool isRead;

  /// Timestamp en que se marcó como leída. Null si no ha sido leída.
  final DateTime? readAt;

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
    this.deliveryId,
    this.isRead = false,
    this.readAt,
  });

  NotificationItem copyWith({
    int? logId,
    String? title,
    String? body,
    String? type,
    NotificationTargetType? targetType,
    String? targetId,
    String? sentBy,
    int? tokensSent,
    int? tokensFailed,
    DateTime? createdAt,
    String? senderName,
    String? deliveryId,
    bool? isRead,
    DateTime? readAt,
  }) {
    return NotificationItem(
      logId: logId ?? this.logId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      sentBy: sentBy ?? this.sentBy,
      tokensSent: tokensSent ?? this.tokensSent,
      tokensFailed: tokensFailed ?? this.tokensFailed,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      deliveryId: deliveryId ?? this.deliveryId,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }

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
        deliveryId,
        isRead,
        readAt,
      ];
}
