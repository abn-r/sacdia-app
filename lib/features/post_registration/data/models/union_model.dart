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
    // Tolerar claves alternativas para el ID
    final rawId = json['union_id'] ?? json['id'];
    final rawCountryId = json['country_id'];

    return UnionModel(
      id: rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      name: (json['name'] as String?) ?? '',
      countryId: rawCountryId is int
          ? rawCountryId
          : (int.tryParse(rawCountryId?.toString() ?? '') ?? 0),
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'union_id': id,
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
