import 'package:equatable/equatable.dart';
import 'package:sacdia_app/core/auth/club_role_names.dart';

const _sectionBoardRoles = {
  ClubRoleNames.director,
  ClubRoleNames.deputyDirector,
  ClubRoleNames.secretary,
  ClubRoleNames.treasurer,
  ClubRoleNames.secretaryTreasurer,
  ClubRoleNames.counselor,
  ClubRoleNames.instructor,
};

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
  final String? clubRoleAssignmentId;

  /// Clase progresiva actual dentro del tipo de club de la sección.
  final String? currentClass;
  final int? currentClassId;

  /// Clase de Guías Mayores, aunque no pertenezca al tipo de esta sección.
  final String? guideMajorClassName;

  /// Indica si el usuario puede ser responsable formal de una clase.
  ///
  /// Regla vigente: debe estar cursando o haber completado Guía Mayor.
  final bool classCounselorEligible;

  /// Estado de inscripción en el club
  final bool isEnrolled;

  /// ID de la sección de club a la que pertenece
  final int? clubSectionId;

  /// Campos adicionales del detalle completo (GET /users/:id)
  final String? blood;
  final String? address;
  final bool? baptism;
  final DateTime? baptismDate;

  /// Fase 4 (solo lectura): `pending` si la persona fue liberada al cumplir la
  /// mayoría de edad y aún no completa el paso (`release_status`). Nulo en
  /// cualquier otro caso o con la liberación apagada. Sin datos personales.
  final String? releaseStatus;

  /// Fin del plazo de la liberación (`release_deadline_at`), si el servidor lo
  /// informa.
  final DateTime? releaseDeadlineAt;

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
    this.guideMajorClassName,
    this.classCounselorEligible = false,
    this.isEnrolled = true,
    this.clubSectionId,
    this.blood,
    this.address,
    this.baptism,
    this.baptismDate,
    this.releaseStatus,
    this.releaseDeadlineAt,
  });

  /// Liberado al cumplir la mayoría de edad y con el paso pendiente (Fase 4).
  bool get isReleasePending => releaseStatus == 'pending';

  /// Cargo de la directiva de la sección, no el rol de miembro.
  bool get isSectionBoard {
    return _sectionBoardRoles.contains(normalizeClubRoleName(clubRole));
  }

  /// Tiene una clase de Guías Mayores, aunque la sección sea de otro club.
  bool get hasGuideMajorClass =>
      classCounselorEligible ||
      (guideMajorClassName?.trim().isNotEmpty ?? false);

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
        guideMajorClassName,
        classCounselorEligible,
        isEnrolled,
        clubSectionId,
        blood,
        address,
        baptism,
        baptismDate,
        releaseStatus,
        releaseDeadlineAt,
      ];
}
