import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/principal_info.dart';

/// Tutor vinculado a un adolescente, tal como lo ve ÉL (sin contacto).
class TeenGuardian extends Equatable {
  /// Id de la tutoría. Sin él no se puede quitar el vínculo.
  final String? guardianshipId;
  final String displayName;
  final String? relationshipTypeName;

  /// `true` cuando un director ya verificó el consentimiento de este tutor.
  final bool verified;

  const TeenGuardian({
    required this.displayName,
    this.guardianshipId,
    this.relationshipTypeName,
    this.verified = false,
  });

  /// El adolescente puede quitar un vínculo que él inició y nadie ha verificado
  /// (por ejemplo, le dio el código a la persona equivocada).
  bool get canBeRemovedByTeen => !verified && guardianshipId != null;

  @override
  List<Object?> get props =>
      [guardianshipId, displayName, relationshipTypeName, verified];
}

/// Código vigente SIN su texto: el servidor solo lo entrega una vez, al
/// generarlo. Aquí solo se sabe que existe uno y cuándo vence.
class OpenTeenLinkCode extends Equatable {
  final DateTime expiresAt;

  const OpenTeenLinkCode({required this.expiresAt});

  @override
  List<Object?> get props => [expiresAt];
}

/// `GET /users/me/supervision`.
class TeenSupervision extends Equatable {
  /// `null` si el servidor no declara estado (cuenta sin supervisión).
  final SupervisionStatus? status;
  final DateTime? pendingSince;
  final List<TeenGuardian> guardians;
  final OpenTeenLinkCode? openLinkCode;
  final bool summaryVisibleToGuardians;

  const TeenSupervision({
    this.status,
    this.pendingSince,
    this.guardians = const [],
    this.openLinkCode,
    this.summaryVisibleToGuardians = true,
  });

  bool get isPending => status == SupervisionStatus.pendingGuardian;

  /// Días que quedan antes de congelar la cuenta, o `null` sin reloj.
  int? daysLeftAt(DateTime now) {
    if (!isPending) return null;
    final since = pendingSince;
    if (since == null) return null;
    final left = kPendingGuardianDeadlineDays -
        now.toUtc().difference(since.toUtc()).inDays;
    return left < 0 ? 0 : left;
  }

  @override
  List<Object?> get props => [
        status,
        pendingSince,
        guardians,
        openLinkCode,
        summaryVisibleToGuardians,
      ];
}

/// `POST /users/me/guardian-link-codes` → `{code, expires_at}`.
///
/// El texto del código solo existe en memoria mientras la pantalla lo muestra:
/// nunca se guarda en disco.
class TeenLinkCode extends Equatable {
  final String code;
  final DateTime expiresAt;

  const TeenLinkCode({required this.code, required this.expiresAt});

  @override
  List<Object?> get props => [code, expiresAt];
}
