import 'package:equatable/equatable.dart';

import 'person_status.dart';

/// Persona con nombre (quien envió la solicitud, quien la autoriza).
class InvestitureActor extends Equatable {
  const InvestitureActor({required this.userId, required this.name});

  final String userId;
  final String name;

  @override
  List<Object?> get props => [userId, name];
}

/// Persona dentro de una solicitud de investidura.
class RequestPerson extends Equatable {
  const RequestPerson({
    required this.personId,
    required this.userId,
    this.userName,
    required this.classId,
    this.className,
    this.sectionName,
    required this.enrollmentId,
    required this.investitureDate,
    required this.status,
    this.canAuthorize = false,
    this.authorizationComment,
    this.rejectionReason,
    this.systemReason,
    this.resolutionCode,
    this.resolvedByName,
  });

  final String personId;
  final String userId;
  final String? userName;
  final int classId;
  final String? className;
  final String? sectionName;
  final int enrollmentId;

  /// Fecha civil (sin zona).
  final DateTime investitureDate;
  final PersonStatus status;

  /// Solo el autorizador con alcance sobre la persona recibe `true`.
  final bool canAuthorize;
  final String? authorizationComment;
  final String? rejectionReason;
  final String? systemReason;
  final String? resolutionCode;
  final String? resolvedByName;

  @override
  List<Object?> get props => [
        personId,
        userId,
        userName,
        classId,
        className,
        sectionName,
        enrollmentId,
        investitureDate,
        status,
        canAuthorize,
        authorizationComment,
        rejectionReason,
        systemReason,
        resolutionCode,
        resolvedByName,
      ];
}

/// Solicitud de investidura de una sección y año.
///
/// Los campos de cabecera (club, distrito, pendientes) vienen en el listado
/// del autorizador; en la vista de la directiva pueden ser nulos.
class InvestitureRequest extends Equatable {
  const InvestitureRequest({
    required this.requestId,
    required this.clubSectionId,
    required this.ecclesiasticalYearId,
    this.clubId,
    this.clubName,
    this.sectionName,
    this.districtName,
    this.pendingCount,
    this.earliestInvestitureDate,
    this.createdAt,
    this.createdBy,
    this.investedCount = 0,
    this.rejectedCount = 0,
    required this.people,
  });

  final String requestId;
  final int clubSectionId;
  final int ecclesiasticalYearId;
  final int? clubId;
  final String? clubName;
  final String? sectionName;
  final String? districtName;
  final int? pendingCount;
  final DateTime? earliestInvestitureDate;
  final DateTime? createdAt;

  /// Quien envió la solicitud; `null` si el backend no lo informa.
  final InvestitureActor? createdBy;

  /// Resumen de una solicitud ya resuelta (listado con `include_resolved`).
  final int investedCount;
  final int rejectedCount;
  final List<RequestPerson> people;

  List<RequestPerson> get pendingPeople => people
      .where((p) => p.status == PersonStatus.pending)
      .toList(growable: false);

  @override
  List<Object?> get props => [
        requestId,
        clubSectionId,
        ecclesiasticalYearId,
        clubId,
        clubName,
        sectionName,
        districtName,
        pendingCount,
        earliestInvestitureDate,
        createdAt,
        createdBy,
        investedCount,
        rejectedCount,
        people,
      ];
}
