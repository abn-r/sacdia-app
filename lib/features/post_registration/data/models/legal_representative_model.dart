import 'package:equatable/equatable.dart';

/// Modelo de representante legal
class LegalRepresentativeModel extends Equatable {
  final int? id;
  final String name;
  final String paternalSurname;
  final String maternalSurname;
  final String phone;
  final String type; // padre, madre, tutor

  const LegalRepresentativeModel({
    this.id,
    required this.name,
    required this.paternalSurname,
    required this.maternalSurname,
    required this.phone,
    required this.type,
  });

  /// Crea una instancia desde JSON
  factory LegalRepresentativeModel.fromJson(Map<String, dynamic> json) {
    return LegalRepresentativeModel(
      id: json['id'] as int?,
      name: json['name'] as String,
      paternalSurname: json['paternal_surname'] as String,
      maternalSurname: json['maternal_surname'] as String,
      phone: json['phone'] as String,
      type: json['type'] as String,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'paternal_surname': paternalSurname,
      'maternal_surname': maternalSurname,
      'phone': phone,
      'type': type,
    };
  }

  /// Crea una copia con campos actualizados
  LegalRepresentativeModel copyWith({
    int? id,
    String? name,
    String? paternalSurname,
    String? maternalSurname,
    String? phone,
    String? type,
  }) {
    return LegalRepresentativeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      paternalSurname: paternalSurname ?? this.paternalSurname,
      maternalSurname: maternalSurname ?? this.maternalSurname,
      phone: phone ?? this.phone,
      type: type ?? this.type,
    );
  }

  /// Obtiene el nombre completo
  String get fullName => '$name $paternalSurname $maternalSurname';

  @override
  List<Object?> get props =>
      [id, name, paternalSurname, maternalSurname, phone, type];
}
