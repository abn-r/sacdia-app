import 'package:equatable/equatable.dart';
import '../../domain/entities/investiture_history_entry.dart';
import '../../domain/entities/investiture_status.dart';

/// Modelo de datos para una entrada del historial de investidura.
///
/// Mapea la respuesta de GET /api/v1/enrollments/:enrollmentId/investiture-history.
class InvestitureHistoryEntryModel extends Equatable {
  final int id;
  final InvestitureAction action;
  final InvestitureStatus? resultingStatus;
  final String? comments;
  final DateTime performedAt;

  final String performerName;
  final String? performerLastName;
  final String? performerRole;

  const InvestitureHistoryEntryModel({
    required this.id,
    required this.action,
    this.resultingStatus,
    this.comments,
    required this.performedAt,
    required this.performerName,
    this.performerLastName,
    this.performerRole,
  });

  factory InvestitureHistoryEntryModel.fromJson(Map<String, dynamic> json) {
    final performer = json['performer'] as Map<String, dynamic>?;

    return InvestitureHistoryEntryModel(
      id: (json['id'] ?? json['history_id']) as int,
      action: InvestitureAction.fromString(
        (json['action'] ?? 'SUBMITTED') as String,
      ),
      resultingStatus: json['resulting_status'] != null
          ? InvestitureStatus.fromString(json['resulting_status'] as String)
          : null,
      comments: json['comments'] as String?,
      performedAt: DateTime.parse(
        (json['performed_at'] ?? json['created_at'] ?? DateTime.now().toIso8601String()) as String,
      ),
      performerName:
          (performer?['name'] ?? json['performer_name'] ?? 'Sistema') as String,
      performerLastName:
          (performer?['last_name'] ?? json['performer_last_name']) as String?,
      performerRole: (performer?['role'] ?? json['performer_role']) as String?,
    );
  }

  InvestitureHistoryEntry toEntity() {
    return InvestitureHistoryEntry(
      id: id,
      action: action,
      resultingStatus: resultingStatus,
      comments: comments,
      performedAt: performedAt,
      performerName: performerName,
      performerLastName: performerLastName,
      performerRole: performerRole,
    );
  }

  @override
  List<Object?> get props => [
        id,
        action,
        resultingStatus,
        comments,
        performedAt,
        performerName,
        performerLastName,
        performerRole,
      ];
}
