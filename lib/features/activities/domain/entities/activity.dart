import 'package:equatable/equatable.dart';

/// Entidad de actividad del club del dominio
class Activity extends Equatable {
  final int id;
  final String title;
  final String? description;
  final DateTime date;
  final String? location;
  final String type; // 'meeting', 'event', 'campout', 'service', etc.
  final int clubId;

  const Activity({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.location,
    required this.type,
    required this.clubId,
  });

  @override
  List<Object?> get props => [id, title, description, date, location, type, clubId];
}
