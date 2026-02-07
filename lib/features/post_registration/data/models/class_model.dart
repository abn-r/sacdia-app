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
    return ClassModel(
      id: json['id'] as int,
      name: json['name'] as String,
      minAge: json['min_age'] as int?,
      maxAge: json['max_age'] as int?,
      clubTypeId: json['club_type_id'] as int,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
