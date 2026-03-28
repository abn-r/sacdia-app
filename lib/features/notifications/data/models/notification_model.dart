import 'package:equatable/equatable.dart';
import '../../domain/entities/notification_item.dart';

/// Modelo de datos para una notificación del historial.
///
/// Mapea la respuesta de GET /notifications/history.
/// Estructura del backend:
/// ```json
/// {
///   "log_id": 1,
///   "title": "...",
///   "body": "...",
///   "type": "...",
///   "target_type": "broadcast",
///   "target_id": null,
///   "sent_by": "uuid",
///   "tokens_sent": 42,
///   "tokens_failed": 0,
///   "created_at": "2025-01-01T00:00:00.000Z",
///   "users": {
///     "user_id": "uuid",
///     "name": "Juan",
///     "paternal_last_name": "Perez",
///     "email": "juan@example.com"
///   }
/// }
/// ```
class NotificationModel extends Equatable {
  final int logId;
  final String title;
  final String body;
  final String type;
  final String targetType;
  final String? targetId;
  final String sentBy;
  final int tokensSent;
  final int tokensFailed;
  final DateTime createdAt;
  final String? senderName;

  const NotificationModel({
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

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final sender = json['users'] as Map<String, dynamic>?;

    String? resolvedSenderName;
    if (sender != null) {
      final name = sender['name'] as String?;
      final lastName = sender['paternal_last_name'] as String?;
      if (name != null) {
        resolvedSenderName = lastName != null ? '$name $lastName' : name;
      }
    }

    return NotificationModel(
      logId: (json['log_id'] as num).toInt(),
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      targetType: (json['target_type'] as String?) ?? 'broadcast',
      targetId: json['target_id'] as String?,
      sentBy: (json['sent_by'] as String?) ?? '',
      tokensSent: (json['tokens_sent'] as num?)?.toInt() ?? 0,
      tokensFailed: (json['tokens_failed'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      senderName: resolvedSenderName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'log_id': logId,
      'title': title,
      'body': body,
      'type': type,
      'target_type': targetType,
      'target_id': targetId,
      'sent_by': sentBy,
      'tokens_sent': tokensSent,
      'tokens_failed': tokensFailed,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationItem toEntity() {
    return NotificationItem(
      logId: logId,
      title: title,
      body: body,
      type: type,
      targetType: NotificationTargetType.fromString(targetType),
      targetId: targetId,
      sentBy: sentBy,
      tokensSent: tokensSent,
      tokensFailed: tokensFailed,
      createdAt: createdAt,
      senderName: senderName,
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
      ];
}
