import 'package:equatable/equatable.dart';

/// Modelo de tipo de relación para contactos de emergencia
class RelationshipTypeModel extends Equatable {
  final int id;
  final String name;

  const RelationshipTypeModel({
    required this.id,
    required this.name,
  });

  /// Crea una instancia desde JSON
  factory RelationshipTypeModel.fromJson(Map<String, dynamic> json) {
    return RelationshipTypeModel(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  List<Object?> get props => [id, name];
}
