import 'package:equatable/equatable.dart';

/// Bloque `acting_for` de `GET /auth/me`.
///
/// Solo viene informado cuando la petición llevó `X-Acting-For`: el tutor
/// (`actorUserId`) está actuando por un dependiente (`dependentUserId`). El
/// servidor lo calcula; la app nunca lo envía ni lo persiste.
class ActingForInfo extends Equatable {
  final String actorUserId;
  final String dependentUserId;
  final String? guardianshipId;

  /// `pending` o `verified`. Puede venir nulo si el servidor no lo informa.
  final String? consentStatus;

  /// Alcances que el servidor concede en esta sesión (`self:read`, ...).
  final List<String> scopes;

  const ActingForInfo({
    required this.actorUserId,
    required this.dependentUserId,
    this.guardianshipId,
    this.consentStatus,
    this.scopes = const [],
  });

  @override
  List<Object?> get props => [
        actorUserId,
        dependentUserId,
        guardianshipId,
        consentStatus,
        scopes,
      ];
}

/// Bloque `family` de `GET /auth/me` (nulo mientras se actúa por un
/// dependiente).
class FamilySummary extends Equatable {
  final bool isGuardian;
  final int dependentsCount;

  const FamilySummary({
    required this.isGuardian,
    required this.dependentsCount,
  });

  @override
  List<Object?> get props => [isGuardian, dependentsCount];
}
