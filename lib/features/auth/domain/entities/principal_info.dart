import 'package:equatable/equatable.dart';

/// Tipo de principal que el servidor resolvió para la sesión (`/auth/me`).
///
/// Lo calcula SIEMPRE el servidor: la app nunca lo deduce de un claim del JWT
/// ni de la edad. Un valor desconocido es [unknown] y se trata con el lado
/// seguro (sin analítica identificada).
enum PrincipalKind {
  /// Adulto o cuenta sin edad conocida.
  user,

  /// Tutor actuando por un dependiente (Fase 2).
  guardianActing,

  /// Menor de 13 a 17 con cuenta propia, bajo supervisión.
  supervisedUser,

  /// Teléfono vinculado de un menor de 13 (Fase 3b).
  linkedDevice,

  /// Valor no reconocido (servidor más nuevo que la app).
  unknown;

  static PrincipalKind parse(Object? raw) => switch (raw) {
        'user' => user,
        'guardian_acting' => guardianActing,
        'supervised_user' => supervisedUser,
        'linked_device' => linkedDevice,
        _ => unknown,
      };
}

/// Estado de la supervisión de un adolescente.
enum SupervisionStatus {
  /// Sin tutor con consentimiento verificado: modo restringido.
  pendingGuardian,

  /// Tutor verificado: la app de miembro completa (menos lo sensible).
  active;

  /// `null` si el valor no es uno de los dos (o viene ausente).
  static SupervisionStatus? parse(Object? raw) => switch (raw) {
        'pending_guardian' => pendingGuardian,
        'active' => active,
        _ => null,
      };
}

/// Tutor vinculado, tal como lo ve el adolescente (sin datos de contacto).
class SupervisionGuardian extends Equatable {
  final String displayName;
  final String? relationshipTypeName;

  const SupervisionGuardian({
    required this.displayName,
    this.relationshipTypeName,
  });

  @override
  List<Object?> get props => [displayName, relationshipTypeName];
}

/// Plazo (en días) que el servidor da a un adolescente sin tutor antes de
/// congelar la cuenta (FP3-06).
const int kPendingGuardianDeadlineDays = 90;

/// Bloque `principal.supervision` de `GET /auth/me`.
class SupervisionInfo extends Equatable {
  final SupervisionStatus status;

  /// Desde cuándo corre el reloj sin tutor (nulo si el servidor no lo informa).
  final DateTime? pendingSince;
  final List<SupervisionGuardian> guardians;
  final bool summaryVisibleToGuardians;

  /// Días restantes que informó el servidor; si falta se calcula con
  /// [daysLeftAt].
  final int? serverDaysLeft;

  const SupervisionInfo({
    required this.status,
    this.pendingSince,
    this.guardians = const [],
    this.summaryVisibleToGuardians = true,
    this.serverDaysLeft,
  });

  bool get isPending => status == SupervisionStatus.pendingGuardian;

  /// Días que quedan antes de congelar la cuenta (nunca negativo). `null` si no
  /// hay reloj (supervisión activa o sin fecha de inicio).
  int? daysLeftAt(DateTime now) {
    if (!isPending) return null;
    final server = serverDaysLeft;
    if (server != null) return server < 0 ? 0 : server;
    final since = pendingSince;
    if (since == null) return null;
    final elapsed = now.toUtc().difference(since.toUtc()).inDays;
    final left = kPendingGuardianDeadlineDays - elapsed;
    return left < 0 ? 0 : left;
  }

  @override
  List<Object?> get props => [
        status,
        pendingSince,
        guardians,
        summaryVisibleToGuardians,
        serverDaysLeft,
      ];
}

/// Bloque `principal` de `GET /auth/me`.
class PrincipalInfo extends Equatable {
  final PrincipalKind kind;

  /// Alcances que el servidor concede (nulo para `user`: sin restricción).
  final List<String>? scopes;
  final SupervisionInfo? supervision;

  const PrincipalInfo({
    required this.kind,
    this.scopes,
    this.supervision,
  });

  @override
  List<Object?> get props => [kind, scopes, supervision];
}

/// Banderas de la familia que el servidor expone en `/auth/me`
/// (`family_features`). Ausentes = apagadas.
class FamilyFeatures extends Equatable {
  final bool teenLogin;
  final bool linkedDevice;
  final bool directorCreateMinor;

  const FamilyFeatures({
    this.teenLogin = false,
    this.linkedDevice = false,
    this.directorCreateMinor = false,
  });

  @override
  List<Object?> get props => [teenLogin, linkedDevice, directorCreateMinor];
}

/// Modo de la cuenta para enrutar la app (FP3-31).
enum AccountMode {
  /// Adulto (o servidor sin soporte de supervisión).
  adult,

  /// Adolescente sin tutor verificado: modo restringido.
  teenPending,

  /// Adolescente con tutor verificado.
  teenSupervised;

  static AccountMode? parse(Object? raw) => switch (raw) {
        'adult' => adult,
        'teen_pending' => teenPending,
        'teen_supervised' => teenSupervised,
        _ => null,
      };
}
