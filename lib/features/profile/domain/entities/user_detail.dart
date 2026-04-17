import 'package:equatable/equatable.dart';

/// Entidad de detalle completo del usuario
class UserDetail extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? paternalSurname;
  final String? maternalSurname;
  final String? avatar;
  final String? phone;
  final DateTime? birthDate;
  final String? gender;
  final String? address;
  final bool baptized;
  final DateTime? baptismDate;
  final String? clubName;
  final String? clubType;
  final String? currentClass;
  final List<String> roles;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;

  const UserDetail({
    required this.id,
    required this.email,
    required this.name,
    this.paternalSurname,
    this.maternalSurname,
    this.avatar,
    this.phone,
    this.birthDate,
    this.gender,
    this.address,
    this.baptized = false,
    this.baptismDate,
    this.clubName,
    this.clubType,
    this.currentClass,
    this.roles = const [],
    this.createdAt,
    this.lastSignInAt,
  });

  /// Obtiene el nombre completo del usuario
  String get fullName {
    final parts = [name, paternalSurname, maternalSurname]
        .where((part) => part != null && part.isNotEmpty)
        .toList();
    return parts.join(' ');
  }

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        paternalSurname,
        maternalSurname,
        avatar,
        phone,
        birthDate,
        gender,
        address,
        baptized,
        baptismDate,
        clubName,
        clubType,
        currentClass,
        roles,
        createdAt,
        lastSignInAt,
      ];
}
