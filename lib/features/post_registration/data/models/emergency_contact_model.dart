import 'package:equatable/equatable.dart';

/// Modelo de contacto de emergencia
class EmergencyContactModel extends Equatable {
  final int? id;
  final String name;
  final String phone;
  final String relationshipTypeId;
  final String? relationshipTypeName;
  final bool primary;

  const EmergencyContactModel({
    this.id,
    required this.name,
    required this.phone,
    required this.relationshipTypeId,
    this.relationshipTypeName,
    this.primary = false,
  });

  /// Crea una instancia desde JSON
  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    final rawTypeId = json['relationship_type_id'] ?? json['relationship_type'];
    final typeId = rawTypeId?.toString() ?? '';

    // La API retorna 'emergency_id' — también tolerar 'id' y 'contact_id'
    final rawId = json['emergency_id'] ?? json['id'] ?? json['contact_id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

    return EmergencyContactModel(
      id: id,
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      relationshipTypeId: typeId,
      relationshipTypeName: json['relationship_type_name'] as String?,
      primary: json['primary'] as bool? ?? false,
    );
  }

  /// Convierte la instancia a JSON para la API
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'relationship_type_id': relationshipTypeId,
      'phone': phone,
      'primary': primary,
    };
  }

  /// Crea una copia con campos actualizados
  EmergencyContactModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? relationshipTypeId,
    String? relationshipTypeName,
    bool? primary,
  }) {
    return EmergencyContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationshipTypeId: relationshipTypeId ?? this.relationshipTypeId,
      relationshipTypeName: relationshipTypeName ?? this.relationshipTypeName,
      primary: primary ?? this.primary,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, phone, relationshipTypeId, relationshipTypeName, primary];
}
