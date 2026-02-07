import 'package:equatable/equatable.dart';
import '../../domain/entities/activity.dart';

/// Modelo de actividad para la capa de datos
class ActivityModel extends Equatable {
  final int id;
  final String title;
  final String? description;
  final DateTime date;
  final String? location;
  final String type;
  final int clubId;

  const ActivityModel({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.location,
    required this.type,
    required this.clubId,
  });

  /// Crea una instancia desde JSON
  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      date: DateTime.parse(json['date'] as String),
      location: json['location'] as String?,
      type: json['type'] as String,
      clubId: json['club_id'] as int,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'location': location,
      'type': type,
      'club_id': clubId,
    };
  }

  /// Convierte el modelo a entidad de dominio
  Activity toEntity() {
    return Activity(
      id: id,
      title: title,
      description: description,
      date: date,
      location: location,
      type: type,
      clubId: clubId,
    );
  }

  /// Crea una copia con campos actualizados
  ActivityModel copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? date,
    String? location,
    String? type,
    int? clubId,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      location: location ?? this.location,
      type: type ?? this.type,
      clubId: clubId ?? this.clubId,
    );
  }

  @override
  List<Object?> get props => [id, title, description, date, location, type, clubId];
}
