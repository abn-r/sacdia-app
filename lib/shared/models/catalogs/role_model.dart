import 'package:equatable/equatable.dart';

/// Modelo para roles de club
class RoleModel extends Equatable {
  final int roleId;
  final String name;
  final String displayName;
  final int? clubTypeId;

  const RoleModel({
    required this.roleId,
    required this.name,
    required this.displayName,
    this.clubTypeId,
  });

  /// Crea una instancia desde JSON
  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      roleId: json['role_id'] as int,
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      clubTypeId: json['club_type_id'] as int?,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'role_id': roleId,
      'name': name,
      'display_name': displayName,
      'club_type_id': clubTypeId,
    };
  }

  @override
  List<Object?> get props => [roleId, name, displayName, clubTypeId];
}
