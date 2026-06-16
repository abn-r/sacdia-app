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
    final performer = _asMap(json['performer']) ??
        _asMap(json['performed_by']) ??
        _asMap(json['users']);
    final performerLastName = _firstNonEmpty([
      performer?['last_name'],
      performer?['paternal_last_name'],
      json['performer_last_name'],
    ]);

    return InvestitureHistoryEntryModel(
      id: _asInt(json['id'] ?? json['history_id']),
      action: InvestitureAction.fromString(
        (json['action'] ?? 'SUBMITTED').toString(),
      ),
      resultingStatus: json['resulting_status'] != null
          ? InvestitureStatus.fromString(json['resulting_status'].toString())
          : null,
      comments: _firstNonEmpty([json['comments'], json['reason']]),
      performedAt: DateTime.parse(
        (json['performed_at'] ??
                json['created_at'] ??
                DateTime.now().toIso8601String())
            .toString(),
      ),
      performerName: _firstNonEmpty([
            performer?['name'],
            performer?['first_name'],
            json['performer_name'],
          ]) ??
          'Sistema',
      performerLastName: performerLastName,
      performerRole: _firstNonEmpty([
        performer?['role_label'],
        performer?['role_name'],
        performer?['role'],
        json['performer_role'],
      ]),
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

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String? _firstNonEmpty(Iterable<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}
