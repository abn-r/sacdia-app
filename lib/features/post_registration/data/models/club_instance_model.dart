import 'package:equatable/equatable.dart';

/// Modelo de instancia de club (tipo específico de club)
class ClubInstanceModel extends Equatable {
  final int id;
  final String clubTypeName;
  final int clubTypeId;
  final int clubId;

  const ClubInstanceModel({
    required this.id,
    required this.clubTypeName,
    required this.clubTypeId,
    required this.clubId,
  });

  /// Crea una instancia desde JSON
  factory ClubInstanceModel.fromJson(Map<String, dynamic> json) {
    return ClubInstanceModel(
      id: json['id'] as int,
      clubTypeName: json['club_type_name'] as String,
      clubTypeId: json['club_type_id'] as int,
      clubId: json['club_id'] as int,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'club_type_name': clubTypeName,
      'club_type_id': clubTypeId,
      'club_id': clubId,
    };
  }

  /// Crea una copia con campos actualizados
  ClubInstanceModel copyWith({
    int? id,
    String? clubTypeName,
    int? clubTypeId,
    int? clubId,
  }) {
    return ClubInstanceModel(
      id: id ?? this.id,
      clubTypeName: clubTypeName ?? this.clubTypeName,
      clubTypeId: clubTypeId ?? this.clubTypeId,
      clubId: clubId ?? this.clubId,
    );
  }

  @override
  List<Object?> get props => [id, clubTypeName, clubTypeId, clubId];
}
