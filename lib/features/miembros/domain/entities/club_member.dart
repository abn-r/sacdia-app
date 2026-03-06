import 'package:equatable/equatable.dart';

/// Entidad que representa un miembro del club
class ClubMember extends Equatable {
  final String userId;
  final String name;
  final String? paternalSurname;
  final String? maternalSurname;
  final String? avatar;
  final String? email;
  final String? phone;
  final DateTime? birthDate;
  final String? gender;

  /// Rol del miembro dentro del club (cargo)
  final String? clubRole;
  final int? clubRoleAssignmentId;

  /// Clase progresiva actual
  final String? currentClass;
  final int? currentClassId;

  /// Estado de inscripción en el club
  final bool isEnrolled;

  /// Tipo de instancia del club al que pertenece
  final String? instanceType;
  final int? instanceId;

  const ClubMember({
    required this.userId,
    required this.name,
    this.paternalSurname,
    this.maternalSurname,
    this.avatar,
    this.email,
    this.phone,
    this.birthDate,
    this.gender,
    this.clubRole,
    this.clubRoleAssignmentId,
    this.currentClass,
    this.currentClassId,
    this.isEnrolled = true,
    this.instanceType,
    this.instanceId,
  });

  /// Nombre completo del miembro
  String get fullName {
    final parts = [name, paternalSurname, maternalSurname]
        .where((p) => p != null && p.isNotEmpty)
        .toList();
    return parts.join(' ');
  }

  /// Iniciales para el avatar fallback
  String get initials {
    final first = name.isNotEmpty ? name[0].toUpperCase() : '';
    final last = paternalSurname?.isNotEmpty == true
        ? paternalSurname![0].toUpperCase()
        : '';
    return '$first$last';
  }

  @override
  List<Object?> get props => [
        userId,
        name,
        paternalSurname,
        maternalSurname,
        avatar,
        email,
        phone,
        birthDate,
        gender,
        clubRole,
        clubRoleAssignmentId,
        currentClass,
        currentClassId,
        isEnrolled,
        instanceType,
        instanceId,
      ];
}
