import 'package:equatable/equatable.dart';

/// Modelo de campo local del catálogo
class LocalFieldModel extends Equatable {
  final int id;
  final String name;
  final int unionId;

  const LocalFieldModel({
    required this.id,
    required this.name,
    required this.unionId,
  });

  /// Crea una instancia desde JSON
  factory LocalFieldModel.fromJson(Map<String, dynamic> json) {
    // Tolerar claves alternativas para el ID
    final rawId = json['local_field_id'] ?? json['id'];
    final rawUnionId = json['union_id'];

    return LocalFieldModel(
      id: rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      name: (json['name'] as String?) ?? '',
      unionId: rawUnionId is int
          ? rawUnionId
          : (int.tryParse(rawUnionId?.toString() ?? '') ?? 0),
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'local_field_id': id,
      'name': name,
      'union_id': unionId,
    };
  }

  /// Crea una copia con campos actualizados
  LocalFieldModel copyWith({
    int? id,
    String? name,
    int? unionId,
  }) {
    return LocalFieldModel(
      id: id ?? this.id,
      name: name ?? this.name,
      unionId: unionId ?? this.unionId,
    );
  }

  @override
  List<Object?> get props => [id, name, unionId];
}
