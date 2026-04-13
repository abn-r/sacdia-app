import 'package:equatable/equatable.dart';
import '../../domain/entities/notification_item.dart';

/// Modelo de datos para una notificación del historial.
///
/// Para usuarios regulares (notification_deliveries JOIN notification_logs):
/// ```json
/// {
///   "delivery_id": "uuid",
///   "read_at": null,
///   "created_at": "2025-01-01T00:00:00.000Z",
///   "log_id": 1,
///   "title": "...",
///   "body": "...",
///   "type": "...",
///   "target_type": "section_role",
///   "source": "admin:manual_send"
/// }
/// ```
///
/// Para admins (notification_logs con users join):
/// ```json
/// {
///   "log_id": 1,
///   "title": "...",
///   "body": "...",
///   "type": "...",
///   "target_type": "all",
///   "target_id": null,
///   "sent_by": "uuid",
///   "tokens_sent": 42,
///   "tokens_failed": 0,
///   "created_at": "2025-01-01T00:00:00.000Z",
///   "users": { "user_id": "uuid", "name": "Juan", "paternal_last_name": "Perez", "email": "..." }
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

  // ── Delivery fields (regular users only) ─────────────────────────────────
  final String? deliveryId;
  final DateTime? readAt;

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
    this.deliveryId,
    this.readAt,
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

    // Parse delivery_id (present for regular users, absent for admins)
    final rawDeliveryId = json['delivery_id'] as String?;

    // Parse read_at — null means unread
    DateTime? parsedReadAt;
    final rawReadAt = json['read_at'];
    if (rawReadAt != null && rawReadAt is String) {
      parsedReadAt = DateTime.tryParse(rawReadAt);
    }

    return NotificationModel(
      logId: (json['log_id'] as num).toInt(),
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      targetType: (json['target_type'] as String?) ?? 'all',
      targetId: json['target_id'] as String?,
      sentBy: (json['sent_by'] as String?) ?? '',
      tokensSent: (json['tokens_sent'] as num?)?.toInt() ?? 0,
      tokensFailed: (json['tokens_failed'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      senderName: resolvedSenderName,
      deliveryId: rawDeliveryId,
      readAt: parsedReadAt,
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
      if (deliveryId != null) 'delivery_id': deliveryId,
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
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
      deliveryId: deliveryId,
      isRead: readAt != null,
      readAt: readAt,
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
        readAt,
      ];
}
