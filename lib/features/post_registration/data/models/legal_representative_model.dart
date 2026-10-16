import 'package:equatable/equatable.dart';

/// Modelo de representante legal
class LegalRepresentativeModel extends Equatable {
  /// UUID del registro (solo lectura; nunca se envía al backend).
  final String? id;
  final String name;
  final String paternalSurname;
  final String maternalSurname;
  final String phone;

  /// UUID del tipo de relación (catálogo `relationship_types`).
  final String relationshipTypeId;

  /// Nombre del tipo de relación (solo lectura, viene en las respuestas).
  final String? relationshipTypeName;

  const LegalRepresentativeModel({
    this.id,
    required this.name,
    required this.paternalSurname,
    required this.maternalSurname,
    required this.phone,
    required this.relationshipTypeId,
    this.relationshipTypeName,
  });

  /// Crea una instancia desde el objeto `data` del backend.
  ///
  /// Si el representante es un usuario registrado, los datos personales se
  /// toman de `representative_user` cuando faltan en la fila.
  factory LegalRepresentativeModel.fromJson(Map<String, dynamic> json) {
    final repUser = json['representative_user'];
    final user = repUser is Map<String, dynamic> ? repUser : const {};
    final relType = json['relationship_types'];
    final type = relType is Map<String, dynamic> ? relType : const {};

    String text(dynamic primary, dynamic fallback) {
      final value = primary ?? fallback;
      return value is String ? value : '';
    }

    final typeId = json['relationship_type_id'] ?? type['relationship_type_id'];
    final typeName = type['name'];

    return LegalRepresentativeModel(
      id: json['id']?.toString(),
      name: text(json['name'], user['name']),
      paternalSurname:
          text(json['paternal_last_name'], user['paternal_last_name']),
      maternalSurname:
          text(json['maternal_last_name'], user['maternal_last_name']),
      phone: text(json['phone'], null),
      relationshipTypeId: typeId?.toString() ?? '',
      relationshipTypeName: typeName is String ? typeName : null,
    );
  }

  /// Convierte la instancia al payload del DTO del backend.
  ///
  /// El backend usa `forbidNonWhitelisted`: solo se envían las claves del DTO.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'paternal_last_name': paternalSurname,
      if (maternalSurname.isNotEmpty) 'maternal_last_name': maternalSurname,
      'phone': phone,
      'relationship_type_id': relationshipTypeId,
    };
  }

  /// Crea una copia con campos actualizados
  LegalRepresentativeModel copyWith({
    String? id,
    String? name,
    String? paternalSurname,
    String? maternalSurname,
    String? phone,
    String? relationshipTypeId,
    String? relationshipTypeName,
  }) {
    return LegalRepresentativeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      paternalSurname: paternalSurname ?? this.paternalSurname,
      maternalSurname: maternalSurname ?? this.maternalSurname,
      phone: phone ?? this.phone,
      relationshipTypeId: relationshipTypeId ?? this.relationshipTypeId,
      relationshipTypeName: relationshipTypeName ?? this.relationshipTypeName,
    );
  }

  /// Obtiene el nombre completo
  String get fullName => '$name $paternalSurname $maternalSurname';

  @override
  List<Object?> get props => [
        id,
        name,
        paternalSurname,
        maternalSurname,
        phone,
        relationshipTypeId,
        relationshipTypeName,
      ];
}
