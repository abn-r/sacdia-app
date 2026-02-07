import 'package:equatable/equatable.dart';

/// Modelo de club del catálogo
class ClubModel extends Equatable {
  final int id;
  final String name;
  final int localFieldId;

  const ClubModel({
    required this.id,
    required this.name,
    required this.localFieldId,
  });

  /// Crea una instancia desde JSON
  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id'] as int,
      name: json['name'] as String,
      localFieldId: json['local_field_id'] as int,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'local_field_id': localFieldId,
    };
  }

  /// Crea una copia con campos actualizados
  ClubModel copyWith({
    int? id,
    String? name,
    int? localFieldId,
  }) {
    return ClubModel(
      id: id ?? this.id,
      name: name ?? this.name,
      localFieldId: localFieldId ?? this.localFieldId,
    );
  }

  @override
  List<Object?> get props => [id, name, localFieldId];
}
