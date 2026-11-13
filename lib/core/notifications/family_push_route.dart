import '../../features/auth/domain/entities/principal_info.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../config/route_names.dart';

/// Pushes de familia de la Fase 3 (FP3-52, FP3-67) y a dónde llevan.
enum FamilyPushKind {
  /// Aviso de seguridad al tutor de un menor con acceso propio (sesión nueva,
  /// contraseña cambiada, bloqueo...).
  security,

  /// Se subió una ficha o evidencia de un menor.
  evidenceUploaded,

  /// El menor cumplió la edad de acceso propio (13): el tutor puede darle uno.
  ageNudge,

  /// Aviso AL adolescente sin tutor (recordatorio a los días 7/30/83) o de que
  /// un tutor se vinculó.
  teenReminder,

  /// Fase 4: faltan 30 días para la mayoría de edad (al menor y a sus tutores).
  majorityNotice,

  /// Fase 4: la persona ya fue liberada al cumplir la mayoría de edad.
  majorityReleased,

  /// Fase 4: recordatorio a la persona liberada que aún no completa el paso.
  majorityReminder,

  /// Fase 4: la cuenta liberada quedó congelada (solo a la persona).
  majorityFrozen,

  /// Fase 4: aviso a los ex tutores o directores de que una persona liberada
  /// sin credenciales necesita un código de acceso.
  majorityHandover,
}

/// Qué `data.type` (o `data.source`) corresponde a cada [FamilyPushKind].
///
/// El servidor envía hoy `dependent_security`, `dependent_evidence_uploaded`,
/// `dependent_age_milestone`, `teen_guardian_reminder` y `teen_guardian_linked`
/// en `data.type`; los nombres `family:*` son el `source` de la notificación y
/// se aceptan por igual por si el servidor los reenvía en el payload.
const Map<String, FamilyPushKind> _kindByType = {
  'family:security': FamilyPushKind.security,
  'dependent_security': FamilyPushKind.security,
  'family:evidence_uploaded': FamilyPushKind.evidenceUploaded,
  'dependent_evidence_uploaded': FamilyPushKind.evidenceUploaded,
  'family:age_nudge': FamilyPushKind.ageNudge,
  'dependent_age_milestone': FamilyPushKind.ageNudge,
  'family:teen_reminder': FamilyPushKind.teenReminder,
  'teen_guardian_reminder': FamilyPushKind.teenReminder,
  'teen_guardian_linked': FamilyPushKind.teenReminder,
  // Fase 4: `data.type` y `source` del servidor.
  'majority_notice': FamilyPushKind.majorityNotice,
  'family:majority:notice': FamilyPushKind.majorityNotice,
  'majority_released': FamilyPushKind.majorityReleased,
  'family:majority:released': FamilyPushKind.majorityReleased,
  'majority_reminder': FamilyPushKind.majorityReminder,
  'family:majority:reminder': FamilyPushKind.majorityReminder,
  'majority_frozen': FamilyPushKind.majorityFrozen,
  'family:majority:frozen': FamilyPushKind.majorityFrozen,
  'majority_handover': FamilyPushKind.majorityHandover,
  'family:majority:handover': FamilyPushKind.majorityHandover,
};

/// Tipo de familia del payload de un push, o `null` si no es uno.
FamilyPushKind? familyPushKindOf(Map<String, dynamic> data) {
  for (final key in const ['type', 'source']) {
    final raw = data[key];
    if (raw is String) {
      final kind = _kindByType[raw.trim()];
      if (kind != null) return kind;
    }
  }
  return null;
}

/// Destino ya resuelto de un push de familia.
class FamilyPushTarget {
  const FamilyPushTarget({
    required this.route,
    this.dependentId,
    this.needsGuardianProfile = false,
  });

  /// Ruta interna (nunca viene del payload).
  final String route;

  /// Id del menor, ya validado, si el destino es su detalle.
  final String? dependentId;

  /// `true` si solo se abre desde el perfil propio del tutor (Mi familia): si
  /// se actúa por un menor hay que salir de él antes.
  final bool needsGuardianProfile;
}

final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Destino de un push de familia para la sesión de [user].
///
/// El modo manda, nunca el payload:
/// - **Tutor** (`user` o `guardian_acting`): el detalle del menor (donde está
///   «Acceso»); sin cambiar de perfil. Un id ausente o con forma rara cae en la
///   lista de Mi familia: el id se interpola en una ruta, así que solo pasa si
///   es un UUID.
/// - **Adolescente sin tutor** (o de estado ilegible): su pantalla de estado.
/// - **Adolescente con tutor**: la bandeja de avisos. Jamás `/family`.
/// - **Adulto liberado** (Fase 4): `/release` o `/release/frozen` según su
///   estado; jamás otra ruta ni un cambio de perfil.
/// - Teléfono vinculado, principal desconocido, cuenta sin edad o sin sesión:
///   `null` (el teléfono vinculado tiene su propia resolución y se IGNORA
///   `dependent_user_id`).
FamilyPushTarget? familyPushTarget({
  required FamilyPushKind kind,
  required Map<String, dynamic> data,
  required UserEntity? user,
}) {
  if (user == null) return null;
  final principalKind = user.principal?.kind ?? PrincipalKind.user;

  switch (principalKind) {
    case PrincipalKind.user:
    case PrincipalKind.guardianActing:
      if (user.mode != AccountMode.adult) return null;
      if (kind == FamilyPushKind.teenReminder) {
        return const FamilyPushTarget(route: RouteNames.notificationsInbox);
      }
      // Fase 4: el aviso de mayoría de edad lleva a Mi familia; el de «necesita
      // un código» al historial de liberados. Los avisos que son de la propia
      // persona liberada no son de un tutor.
      if (kind == FamilyPushKind.majorityNotice) {
        return const FamilyPushTarget(
          route: RouteNames.family,
          needsGuardianProfile: true,
        );
      }
      if (kind == FamilyPushKind.majorityHandover) {
        return const FamilyPushTarget(
          route: RouteNames.familyReleased,
          needsGuardianProfile: true,
        );
      }
      if (kind == FamilyPushKind.majorityReleased ||
          kind == FamilyPushKind.majorityReminder ||
          kind == FamilyPushKind.majorityFrozen) {
        return null;
      }
      final raw = data['dependent_user_id']?.toString().trim() ?? '';
      if (_uuid.hasMatch(raw)) {
        return FamilyPushTarget(
          route: RouteNames.familyDetailPath(raw),
          dependentId: raw,
          needsGuardianProfile: true,
        );
      }
      return const FamilyPushTarget(
        route: RouteNames.family,
        needsGuardianProfile: true,
      );
    case PrincipalKind.supervisedUser:
      return user.mode == AccountMode.teenSupervised
          ? const FamilyPushTarget(route: RouteNames.notificationsInbox)
          : const FamilyPushTarget(route: RouteNames.teenPendingHome);
    case PrincipalKind.releasedUser:
      // Solo los avisos propios de la persona; un tutor o director no los
      // recibe en esta sesión. El estado lo decide `/auth/me`, no el payload.
      if (user.mode != AccountMode.released) return null;
      if (kind == FamilyPushKind.majorityReleased ||
          kind == FamilyPushKind.majorityReminder ||
          kind == FamilyPushKind.majorityFrozen ||
          kind == FamilyPushKind.majorityNotice) {
        return FamilyPushTarget(
          route: user.isReleaseFrozen
              ? RouteNames.releaseFrozen
              : RouteNames.release,
        );
      }
      return null;
    case PrincipalKind.linkedDevice:
    case PrincipalKind.ageUnknownUser:
    case PrincipalKind.unknown:
      return null;
  }
}

/// ¿Puede preguntarse «¿cambiar al perfil de Ana?» a esta sesión?
///
/// Solo a quien puede actuar por un menor: una cuenta adulta (`user`) o un
/// tutor que ya está actuando. Un adolescente, un teléfono vinculado o una
/// cuenta restringida IGNORAN `dependent_user_id`. Sin usuario (sesión aún sin
/// resolver) decide el manejador, que sale solo si no hay sesión.
bool mayConfirmProfileSwitch(UserEntity? user) {
  if (user == null) return true;
  final kind = user.principal?.kind ?? PrincipalKind.user;
  return kind == PrincipalKind.user || kind == PrincipalKind.guardianActing;
}
