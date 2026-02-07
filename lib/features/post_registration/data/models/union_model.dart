import 'package:equatable/equatable.dart';

/// Modelo de unión del catálogo
class UnionModel extends Equatable {
  final int id;
  final String name;
  final int countryId;

  const UnionModel({
    required this.id,
    required this.name,
    required this.countryId,
  });

  /// Crea una instancia desde JSON
  factory UnionModel.fromJson(Map<String, dynamic> json) {
    return UnionModel(
      id: json['id'] as int,
      name: json['name'] as String,
      countryId: json['country_id'] as int,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country_id': countryId,
    };
  }

  /// Crea una copia con campos actualizados
  UnionModel copyWith({
    int? id,
    String? name,
    int? countryId,
  }) {
    return UnionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      countryId: countryId ?? this.countryId,
    );
  }

  @override
  List<Object?> get props => [id, name, countryId];
}
