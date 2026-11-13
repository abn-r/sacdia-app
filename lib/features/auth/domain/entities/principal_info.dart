import 'package:equatable/equatable.dart';

/// Tipo de principal que el servidor resolvió para la sesión (`/auth/me`).
///
/// Lo calcula SIEMPRE el servidor: la app nunca lo deduce de un claim del JWT
/// ni de la edad. Un valor desconocido es [unknown] y falla cerrado: cuenta
/// restringida (`AccountMode.restricted`), analítica anónima, nunca adulto.
enum PrincipalKind {
  /// Adulto o cuenta sin edad conocida.
  user,

  /// Tutor actuando por un dependiente (Fase 2).
  guardianActing,

  /// Menor de 13 a 17 con cuenta propia, bajo supervisión.
  supervisedUser,

  /// Teléfono vinculado de un menor de 13 (Fase 3b).
  linkedDevice,

  /// Cuenta SIN fecha de nacimiento y con el post-registro incompleto (p. ej.
  /// un alta nueva con Google o Apple): restringida hasta que el paso 2 guarde
  /// la fecha. Sin supervisión ni familia. No es un adulto.
  ageUnknownUser,

  /// Adulto liberado al cumplir la mayoría de edad que aún no reclamó su cuenta
  /// (Fase 4): ve solo el flujo de liberación (`/release`). Una app anterior a
  /// la Fase 4 lo lee como [unknown] y falla cerrado.
  releasedUser,

  /// Valor no reconocido (servidor más nuevo que la app).
  unknown;

  static PrincipalKind parse(Object? raw) => switch (raw) {
        'user' => user,
        'guardian_acting' => guardianActing,
        'supervised_user' => supervisedUser,
        'linked_device' => linkedDevice,
        'age_unknown_user' => ageUnknownUser,
        'released_user' => releasedUser,
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

  /// Id de la tutoría (`guardianship_id`); nulo en servidores anteriores.
  final String? guardianshipId;

  /// `consent_status` crudo: `pending` | `verified`. Nulo si falta.
  final String? consentStatus;

  const SupervisionGuardian({
    required this.displayName,
    this.relationshipTypeName,
    this.guardianshipId,
    this.consentStatus,
  });

  @override
  List<Object?> get props =>
      [displayName, relationshipTypeName, guardianshipId, consentStatus];
}

/// Plazo (en días) que el servidor da a un adolescente sin tutor antes de
/// pausar la cuenta (FP3-06). La pausa no elimina la cuenta.
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

  /// Desde cuándo la cuenta está en pausa por no tener un tutor verificado
  /// (`frozen_at`). Nulo si no está en pausa. La pausa nunca elimina la cuenta:
  /// se levanta sola cuando un tutor queda vinculado Y verificado.
  final DateTime? frozenAt;

  /// Fecha (calendario, solo día) en que cumplirá la mayoría de edad. El
  /// servidor solo la informa dentro de la ventana de aviso de 30 días y con la
  /// liberación activa (Fase 4); nula en cualquier otro caso.
  final DateTime? majorityDate;

  /// El aviso de mayoría de edad ya se envió (`release_notice_sent`).
  final bool majorityNoticeSent;

  const SupervisionInfo({
    required this.status,
    this.pendingSince,
    this.guardians = const [],
    this.summaryVisibleToGuardians = true,
    this.serverDaysLeft,
    this.frozenAt,
    this.majorityDate,
    this.majorityNoticeSent = false,
  });

  /// Hay una mayoría de edad próxima que mostrar al adolescente.
  bool get hasMajorityNotice => majorityNoticeSent && majorityDate != null;

  /// Días que faltan para [majorityDate] (nunca negativo), o `null` sin fecha.
  int? majorityDaysLeftAt(DateTime now) {
    final date = majorityDate;
    if (date == null) return null;
    final today = DateTime.utc(now.year, now.month, now.day);
    final target = DateTime.utc(date.year, date.month, date.day);
    final left = target.difference(today).inDays;
    return left < 0 ? 0 : left;
  }

  bool get isPending => status == SupervisionStatus.pendingGuardian;

  /// La cuenta está en pausa a la espera de un tutor verificado.
  bool get isPaused => isPending && frozenAt != null;

  /// Días que quedan antes de pausar la cuenta (nunca negativo). `null` si no
  /// hay reloj (supervisión activa, ya en pausa o sin fecha de inicio).
  int? daysLeftAt(DateTime now) {
    if (!isPending || isPaused) return null;
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
        frozenAt,
        majorityDate,
        majorityNoticeSent,
      ];
}

/// Estado de la liberación de un adulto (`principal.release.status`).
enum ReleaseStatus {
  /// Liberado y con el plazo corriendo (o ya sin tutores): debe aceptar y, si
  /// falta, agregar un correo.
  pending,

  /// Congelado por no completar el paso a tiempo. NUNCA se borra solo (R6):
  /// solo conserva sus datos, ocultos, hasta que vuelva.
  frozen;

  /// `null` si falta o no se reconoce.
  static ReleaseStatus? parse(Object? raw) => switch (raw) {
        'pending' => pending,
        'frozen' => frozen,
        _ => null,
      };
}

/// Cómo inicia sesión la persona liberada.
enum ReleaseLoginMethod {
  email,
  handle;

  static ReleaseLoginMethod? parse(Object? raw) => switch (raw) {
        'email' => email,
        'handle' => handle,
        _ => null,
      };
}

/// Bloque `principal.release` de `GET /auth/me` (Fase 4): lo que la app
/// necesita para dibujar el flujo de liberación de un adulto recién liberado.
class ReleaseInfo extends Equatable {
  final ReleaseStatus status;

  /// Nulos hasta que el cron persiste la liberación (compuerta perezosa).
  final DateTime? releasedAt;
  final DateTime? deadlineAt;
  final DateTime? frozenAt;

  /// Sin uso mientras no haya borrado automático (R6): el servidor no lo manda
  /// para una congelación por mayoría de edad. Se parsea por compatibilidad y
  /// la app NUNCA lo muestra.
  final DateTime? purgeAfter;

  /// Falta aceptar los Términos y la Privacidad vigentes.
  final bool needsAcceptance;

  /// Falta agregar un correo (un correo sin verificar basta, R5).
  final bool needsEmail;
  final ReleaseLoginMethod? loginMethod;

  const ReleaseInfo({
    required this.status,
    this.releasedAt,
    this.deadlineAt,
    this.frozenAt,
    this.purgeAfter,
    this.needsAcceptance = true,
    this.needsEmail = false,
    this.loginMethod,
  });

  bool get isFrozen => status == ReleaseStatus.frozen;

  /// Días hasta el cierre del plazo (nunca negativo), o `null` sin plazo o ya
  /// congelado.
  int? daysLeftAt(DateTime now) {
    final deadline = deadlineAt;
    if (deadline == null || isFrozen) return null;
    final left = deadline.toUtc().difference(now.toUtc()).inHours;
    if (left <= 0) return 0;
    return (left / 24).ceil();
  }

  @override
  List<Object?> get props => [
        status,
        releasedAt,
        deadlineAt,
        frozenAt,
        purgeAfter,
        needsAcceptance,
        needsEmail,
        loginMethod,
      ];
}

/// Bloque `principal.device` de `GET /auth/me` para un teléfono vinculado.
class DeviceInfo extends Equatable {
  final String? linkedDeviceId;
  final String? label;
  final DateTime? pairedAt;

  /// Club del menor (`/auth/me.club{club_id, club_name, club_type}` de un
  /// teléfono vinculado, que no trae `authorization`). Se guarda aquí para que
  /// viaje con el principal.
  final int? clubId;
  final String? clubName;
  final String? clubType;

  const DeviceInfo({
    this.linkedDeviceId,
    this.label,
    this.pairedAt,
    this.clubId,
    this.clubName,
    this.clubType,
  });

  @override
  List<Object?> get props =>
      [linkedDeviceId, label, pairedAt, clubId, clubName, clubType];
}

/// Bloque `principal` de `GET /auth/me`.
class PrincipalInfo extends Equatable {
  final PrincipalKind kind;

  /// Alcances que el servidor concede (nulo para `user`: sin restricción).
  final List<String>? scopes;
  final SupervisionInfo? supervision;

  /// Solo para un teléfono vinculado (`linked_device`).
  final DeviceInfo? device;

  /// Solo para un adulto liberado (`released_user`, Fase 4).
  final ReleaseInfo? release;

  const PrincipalInfo({
    required this.kind,
    this.scopes,
    this.supervision,
    this.device,
    this.release,
  });

  @override
  List<Object?> get props => [kind, scopes, supervision, device, release];
}

/// Banderas de la familia que el servidor expone en `/auth/me`
/// (`family_features`). Ausentes = apagadas.
class FamilyFeatures extends Equatable {
  final bool teenLogin;
  final bool linkedDevice;
  final bool directorCreateMinor;

  /// Liberación al cumplir la mayoría de edad (Fase 4). Apagada = ninguna
  /// pantalla, aviso ni entrada de la Fase 4 (FP4-67).
  final bool majorityRelease;

  const FamilyFeatures({
    this.teenLogin = false,
    this.linkedDevice = false,
    this.directorCreateMinor = false,
    this.majorityRelease = false,
  });

  @override
  List<Object?> get props =>
      [teenLogin, linkedDevice, directorCreateMinor, majorityRelease];
}

/// Modo de la cuenta para enrutar la app (FP3-31).
enum AccountMode {
  /// Adulto (o servidor sin soporte de supervisión).
  adult,

  /// Adolescente sin tutor verificado: modo restringido.
  teenPending,

  /// Adolescente con tutor verificado.
  teenSupervised,

  /// Sin fecha de nacimiento y con el post-registro incompleto (`/auth/me.mode`
  /// = `profile_incomplete`). Solo puede completar el post-registro; en cuanto
  /// el paso 2 guarda la fecha, el servidor lo pasa a `teen_pending` o `adult`.
  profileIncomplete,

  /// Teléfono vinculado de un menor de 13 (Fase 3b). Cáscara propia: sin
  /// perfil, sin Mi familia, sin cuenta (`principal.kind == linked_device`).
  linkedDevice,

  /// Adulto liberado que aún no reclamó su cuenta (Fase 4,
  /// `principal.kind == released_user`): solo el flujo `/release` (pendiente) o
  /// `/release/frozen`. Nunca es un adulto completo ni se identifica en
  /// analítica.
  released,

  /// Modo o principal que la app no reconoce (servidor más nuevo). Falla
  /// cerrado: nunca se trata como adulto.
  restricted;

  /// `null` si el valor falta (el modo se deriva del principal). Un texto que
  /// la app no reconoce es [restricted]: fallar cerrado, no abierto.
  static AccountMode? parse(Object? raw) => switch (raw) {
        null => null,
        'adult' => adult,
        'teen_pending' => teenPending,
        'teen_supervised' => teenSupervised,
        'device' => linkedDevice,
        'profile_incomplete' => profileIncomplete,
        'released' => released,
        String() => restricted,
        _ => null,
      };
}
