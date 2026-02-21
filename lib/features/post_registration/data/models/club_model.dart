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
    // Tolerar claves alternativas para el ID
    final rawId = json['club_id'] ?? json['id'];
    final rawFieldId = json['local_field_id'];

    return ClubModel(
      id: rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      name: (json['name'] as String?) ?? '',
      localFieldId: rawFieldId is int
          ? rawFieldId
          : (int.tryParse(rawFieldId?.toString() ?? '') ?? 0),
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'club_id': id,
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
