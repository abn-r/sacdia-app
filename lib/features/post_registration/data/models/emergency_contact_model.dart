import 'package:equatable/equatable.dart';

/// Modelo de contacto de emergencia
class EmergencyContactModel extends Equatable {
  final int? id;
  final String name;
  final String phone;
  final int relationshipTypeId;
  final String? relationshipTypeName;

  const EmergencyContactModel({
    this.id,
    required this.name,
    required this.phone,
    required this.relationshipTypeId,
    this.relationshipTypeName,
  });

  /// Crea una instancia desde JSON
  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: json['id'] as int?,
      name: json['name'] as String,
      phone: json['phone'] as String,
      relationshipTypeId: json['relationship_type_id'] as int,
      relationshipTypeName: json['relationship_type_name'] as String?,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'relationship_type_id': relationshipTypeId,
      if (relationshipTypeName != null)
        'relationship_type_name': relationshipTypeName,
    };
  }

  /// Crea una copia con campos actualizados
  EmergencyContactModel copyWith({
    int? id,
    String? name,
    String? phone,
    int? relationshipTypeId,
    String? relationshipTypeName,
  }) {
    return EmergencyContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationshipTypeId: relationshipTypeId ?? this.relationshipTypeId,
      relationshipTypeName: relationshipTypeName ?? this.relationshipTypeName,
    );
  }

  @override
  List<Object?> get props => [id, name, phone, relationshipTypeId, relationshipTypeName];
}
