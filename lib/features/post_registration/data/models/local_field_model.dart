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
    return LocalFieldModel(
      id: json['id'] as int,
      name: json['name'] as String,
      unionId: json['union_id'] as int,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
