import 'package:equatable/equatable.dart';

/// Modelo de país del catálogo
class CountryModel extends Equatable {
  final int id;
  final String name;

  const CountryModel({
    required this.id,
    required this.name,
  });

  /// Crea una instancia desde JSON
  factory CountryModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['country_id'] ?? json['id'];
    return CountryModel(
      id: rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      name: (json['name'] as String?) ?? '',
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'country_id': id,
      'name': name,
    };
  }

  /// Crea una copia con campos actualizados
  CountryModel copyWith({
    int? id,
    String? name,
  }) {
    return CountryModel(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  List<Object?> get props => [id, name];
}
