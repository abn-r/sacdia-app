import 'package:equatable/equatable.dart';

/// Modelo de tipo de relación para contactos de emergencia
class RelationshipTypeModel extends Equatable {
  final String id;
  final String name;

  const RelationshipTypeModel({
    required this.id,
    required this.name,
  });

  /// Crea una instancia desde JSON
  factory RelationshipTypeModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['relationship_type_id'] ?? json['id'];
    return RelationshipTypeModel(
      id: rawId?.toString() ?? '',
      name: (json['name'] as String?) ?? '',
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'relationship_type_id': id,
      'name': name,
    };
  }

  @override
  List<Object?> get props => [id, name];
}
