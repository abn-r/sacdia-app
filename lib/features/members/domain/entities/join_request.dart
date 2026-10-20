import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';

/// Estado de una solicitud de ingreso al club
enum JoinRequestStatus {
  pending,
  approved,
  rejected,
}

/// Extensión para obtener el label localizado
extension JoinRequestStatusLabel on JoinRequestStatus {
  String get label {
    switch (this) {
      case JoinRequestStatus.pending:
        return tr('domain.statuses.pending');
      case JoinRequestStatus.approved:
        return tr('domain.statuses.approved');
      case JoinRequestStatus.rejected:
        return tr('domain.statuses.rejected');
    }
  }
}

/// Estado del consentimiento del tutor de un menor que pide entrar al club.
enum JoinRequestConsentStatus {
  pending,
  verified;

  /// Un valor desconocido se trata como `pending`: es el lado seguro (no deja
  /// aprobar sin verificar).
  static JoinRequestConsentStatus parse(Object? raw) =>
      raw == 'verified' ? verified : pending;
}

/// Por qué quien consulta NO puede verificar un consentimiento (cuatro ojos),
/// según el servidor (`consent.viewer_verify_block`).
enum ConsentVerifyBlock {
  /// Custodia del club y quien consulta registró al menor, subió la ficha
  /// vigente o cedió al menor al club.
  selfCustodian,

  /// Quien consulta es tutor vigente del menor.
  selfGuardian;

  /// Un valor desconocido o ausente es `null` (el servidor sigue siendo la
  /// autoridad con su 403).
  static ConsentVerifyBlock? parse(Object? raw) => switch (raw) {
        'self_custodian' => selfCustodian,
        'self_guardian' => selfGuardian,
        _ => null,
      };
}

/// Tutor de un menor, tal como lo ve el director en la solicitud.
class ConsentGuardianRef extends Equatable {
  final String displayName;
  final String? relationshipTypeName;
  final bool isPrimary;

  const ConsentGuardianRef({
    required this.displayName,
    this.relationshipTypeName,
    this.isPrimary = false,
  });

  @override
  List<Object?> get props => [displayName, relationshipTypeName, isPrimary];
}

/// Bloque `consent` de una solicitud: existe solo si el solicitante es un menor
/// sin cuenta (dependiente). Para adultos el backend manda `null`.
class JoinRequestConsent extends Equatable {
  final String? guardianshipId;
  final JoinRequestConsentStatus status;

  /// Ya hay una ficha firmada vigente subida (por el tutor o por el director).
  final bool evidenceUploaded;
  final List<ConsentGuardianRef> guardians;

  /// Tiene perfil de dependiente (`consent.dependent`).
  final bool dependent;

  /// Hay un tutor (no el club) vinculado (`consent.guardian_linked`). `null` si
  /// el servidor no lo informa: entonces no se asume custodia.
  final bool? guardianLinked;

  /// Veredicto del servidor para QUIEN CONSULTA (`consent.viewer_can_verify`).
  /// `true` solo si hay algo que verificar (ficha vigente subida, consentimiento
  /// pendiente) y no lo impide el cuatro ojos; `false` si lo impide
  /// ([viewerVerifyBlock]) o si al cargar la lista aún no había nada que
  /// verificar (sin ficha, ya verificado). `null` si el servidor no lo informa.
  final bool? viewerCanVerify;

  /// Por qué el servidor impide verificar a quien consulta; `null` si puede o si
  /// no había nada que verificar al cargar la lista. Solo este valor desactiva
  /// "Confirmar": `viewerCanVerify == false` sin motivo es una foto vieja (la
  /// ficha pudo subirse después).
  final ConsentVerifyBlock? viewerVerifyBlock;

  const JoinRequestConsent({
    required this.status,
    this.guardianshipId,
    this.evidenceUploaded = false,
    this.guardians = const [],
    this.dependent = true,
    this.guardianLinked,
    this.viewerCanVerify,
    this.viewerVerifyBlock,
  });

  /// El menor está bajo CUSTODIA del club: tiene perfil pero ningún tutor
  /// vinculado. Solo entonces rige el cuatro ojos (quien lo registró o subió la
  /// ficha no puede verificar). Sin el dato del servidor, no se asume.
  bool get isCustody => dependent && guardianLinked == false;

  bool get isPending => status == JoinRequestConsentStatus.pending;
  bool get isVerified => status == JoinRequestConsentStatus.verified;

  @override
  List<Object?> get props => [
        guardianshipId,
        status,
        evidenceUploaded,
        guardians,
        dependent,
        guardianLinked,
        viewerCanVerify,
        viewerVerifyBlock,
      ];
}

/// Entidad que representa una solicitud de ingreso al club
class JoinRequest extends Equatable {
  final String assignmentId;
  final String userId;
  final String name;
  final String? paternalSurname;
  final String? maternalSurname;
  final String? avatar;
  final String? email;
  final JoinRequestStatus status;
  final DateTime? requestedAt;
  final DateTime? resolvedAt;

  /// `null` para adultos; presente para menores sin cuenta (FP-72).
  final JoinRequestConsent? consent;

  const JoinRequest({
    required this.assignmentId,
    required this.userId,
    required this.name,
    this.paternalSurname,
    this.maternalSurname,
    this.avatar,
    this.email,
    required this.status,
    this.requestedAt,
    this.resolvedAt,
    this.consent,
  });

  /// Sección de la solicitud: el prefijo de [assignmentId]
  /// (`<sectionId>/membership-requests/<id>`). `null` si no viene.
  int? get clubSectionId {
    final slash = assignmentId.indexOf('/');
    return slash <= 0 ? null : int.tryParse(assignmentId.substring(0, slash));
  }

  /// Es un menor cuya solicitud necesita el consentimiento del tutor.
  bool get isMinorWithConsent => consent != null;

  /// El director NO puede aprobar todavía: falta verificar la ficha firmada.
  bool get consentPending =>
      status == JoinRequestStatus.pending && (consent?.isPending ?? false);

  /// Nombre completo del solicitante
  String get fullName {
    final parts = [name, paternalSurname, maternalSurname]
        .where((p) => p != null && p.isNotEmpty)
        .toList();
    return parts.join(' ');
  }

  /// Iniciales para avatar fallback
  String get initials {
    final first = name.isNotEmpty ? name[0].toUpperCase() : '';
    final last = paternalSurname?.isNotEmpty == true
        ? paternalSurname![0].toUpperCase()
        : '';
    return '$first$last';
  }

  @override
  List<Object?> get props => [
        assignmentId,
        userId,
        name,
        paternalSurname,
        maternalSurname,
        avatar,
        email,
        status,
        requestedAt,
        resolvedAt,
        consent,
      ];
}
