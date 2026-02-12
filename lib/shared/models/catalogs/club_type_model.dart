import 'package:equatable/equatable.dart';

/// Modelo para tipos de club (Aventureros, Conquistadores, Guías Mayores)
class ClubTypeModel extends Equatable {
  final int clubTypeId;
  final String name;
  final String? description;

  const ClubTypeModel({
    required this.clubTypeId,
    required this.name,
    this.description,
  });

  /// Crea una instancia desde JSON
  factory ClubTypeModel.fromJson(Map<String, dynamic> json) {
    return ClubTypeModel(
      clubTypeId: json['club_type_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'club_type_id': clubTypeId,
      'name': name,
      'description': description,
    };
  }

  @override
  List<Object?> get props => [clubTypeId, name, description];
}
