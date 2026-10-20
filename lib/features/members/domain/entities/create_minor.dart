import 'package:equatable/equatable.dart';

/// Datos para que un director registre a un menor desde una sección del club
/// (`POST /club-sections/:clubSectionId/dependents`, FP3-61).
///
/// No hay correo, acceso ni contraseña: el menor queda SIN cuenta, bajo la
/// custodia del club. La declaración bajo protesta y las versiones legales las
/// aporta el director (aceptación en nombre del menor).
class CreateMinorInput extends Equatable {
  final int clubSectionId;
  final String name;
  final String paternalLastName;
  final String? maternalLastName;

  /// `YYYY-MM-DD`.
  final String birthday;

  /// `M` o `F`; opcional.
  final String? gender;
  final bool swornDeclaration;
  final String acceptedTermsVersion;
  final String acceptedPrivacyVersion;

  const CreateMinorInput({
    required this.clubSectionId,
    required this.name,
    required this.paternalLastName,
    required this.birthday,
    required this.swornDeclaration,
    required this.acceptedTermsVersion,
    required this.acceptedPrivacyVersion,
    this.maternalLastName,
    this.gender,
  });

  @override
  List<Object?> get props => [
        clubSectionId,
        name,
        paternalLastName,
        maternalLastName,
        birthday,
        gender,
        swornDeclaration,
        acceptedTermsVersion,
        acceptedPrivacyVersion,
      ];
}

/// Respuesta `201` de la alta: el menor, su custodia (consentimiento pendiente)
/// y la solicitud de ingreso PENDIENTE. Nunca es un miembro todavía.
class CreatedMinor extends Equatable {
  final String userId;
  final String name;
  final String? birthday;
  final int? age;
  final String guardianshipId;
  final String consentStatus;
  final String assignmentId;
  final int? clubSectionId;

  const CreatedMinor({
    required this.userId,
    required this.name,
    required this.guardianshipId,
    required this.assignmentId,
    this.birthday,
    this.age,
    this.consentStatus = 'pending',
    this.clubSectionId,
  });

  /// Un valor distinto de `verified` es pendiente: el lado seguro.
  bool get consentPending => consentStatus != 'verified';

  @override
  List<Object?> get props => [
        userId,
        name,
        birthday,
        age,
        guardianshipId,
        consentStatus,
        assignmentId,
        clubSectionId,
      ];
}
