import 'package:equatable/equatable.dart';

/// Modelo de clase progresiva del catálogo
class ClassModel extends Equatable {
  final int id;
  final String name;
  final int? minAge;
  final int? maxAge;
  final int clubTypeId;

  const ClassModel({
    required this.id,
    required this.name,
    this.minAge,
    this.maxAge,
    required this.clubTypeId,
  });

  /// Crea una instancia desde JSON
  factory ClassModel.fromJson(Map<String, dynamic> json) {
    // Tolerar claves alternativas para el ID
    final rawId = json['class_id'] ?? json['id'];
    final rawClubTypeId = json['club_type_id'];

    return ClassModel(
      id: rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      name: (json['name'] as String?) ?? '',
      minAge: (json['minimum_age'] ?? json['min_age']) as int?,
      maxAge: json['max_age'] as int?,
      clubTypeId: rawClubTypeId is int
          ? rawClubTypeId
          : (int.tryParse(rawClubTypeId?.toString() ?? '') ?? 0),
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'class_id': id,
      'name': name,
      'min_age': minAge,
      'max_age': maxAge,
      'club_type_id': clubTypeId,
    };
  }

  /// Crea una copia con campos actualizados
  ClassModel copyWith({
    int? id,
    String? name,
    int? minAge,
    int? maxAge,
    int? clubTypeId,
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      clubTypeId: clubTypeId ?? this.clubTypeId,
    );
  }

  @override
  List<Object?> get props => [id, name, minAge, maxAge, clubTypeId];
}
