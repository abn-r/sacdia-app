import 'package:equatable/equatable.dart';

import 'acting_for_info.dart';
import 'authorization_snapshot.dart';
import 'principal_info.dart';

/// Entidad de usuario para la capa de dominio
class UserEntity extends Equatable {
  final String id;

  /// Nulo para los perfiles de dependientes (menores sin cuenta): no tienen
  /// correo. Todo consumidor debe tolerarlo.
  final String? email;
  final String? name;
  final String? avatar;
  final DateTime? birthday;
  final Map<String, dynamic>? metadata;
  final AuthorizationSnapshot? authorization;
  final DateTime? lastSignInAt;
  final DateTime? createdAt;
  final bool postRegisterComplete;

  /// El servidor exige aceptar una versión vigente de Términos o Privacidad.
  ///
  /// Se deriva de `/auth/me` en cada carga y nunca se cachea. Debe formar parte
  /// de `props`: si no, al limpiarse el flag el estado sería igual al anterior
  /// y el router no se refrescaría.
  final bool legalAcceptancePending;

  /// Presente solo cuando `/auth/me` se pidió con `X-Acting-For`. Se deriva en
  /// cada carga y nunca se cachea.
  final ActingForInfo? actingFor;

  /// Resumen de tutoría (`is_guardian`, `dependents_count`). Nulo mientras se
  /// actúa por un dependiente. Se deriva en cada carga y nunca se cachea.
  final FamilySummary? family;

  /// Principal que el servidor resolvió (`user`, `supervised_user`...). Se
  /// deriva en cada carga y nunca se cachea. Nulo = no informado (servidor
  /// anterior a la Fase 3, sesión restaurada sin red o login recién hecho).
  final PrincipalInfo? principal;

  /// Banderas de la familia (`family_features`). Nulo = no informadas.
  final FamilyFeatures? familyFeatures;

  /// `/auth/me.analytics_anonymous`: `true` obliga a la analítica anónima.
  /// Nulo (ausente o desconocido) cuenta como anónimo: solo `false` explícito
  /// permite identificar (FP3-30, falla cerrado).
  final bool? analyticsAnonymous;

  /// Modo que el servidor declaró de forma explícita (`/auth/me.mode`).
  final AccountMode? serverMode;

  const UserEntity({
    required this.id,
    this.email,
    this.name,
    this.avatar,
    this.birthday,
    this.metadata,
    this.authorization,
    this.lastSignInAt,
    this.createdAt,
    this.postRegisterComplete = false,
    this.legalAcceptancePending = false,
    this.actingFor,
    this.family,
    this.principal,
    this.familyFeatures,
    this.analyticsAnonymous,
    this.serverMode,
  });

  /// Modo de la cuenta para enrutar (FP3-31). Un adolescente supervisado cuyo
  /// estado no se pudo leer cuenta como pendiente (el lado restrictivo); un
  /// principal ausente es adulto: el servidor sigue siendo quien deniega.
  AccountMode get mode {
    final explicit = serverMode;
    if (explicit != null) return explicit;
    final p = principal;
    if (p != null && p.kind == PrincipalKind.supervisedUser) {
      return p.supervision?.status == SupervisionStatus.active
          ? AccountMode.teenSupervised
          : AccountMode.teenPending;
    }
    return AccountMode.adult;
  }

  /// Cuenta de un menor bajo supervisión (pendiente o con tutor).
  bool get isSupervisedTeen => mode != AccountMode.adult;

  /// Se puede identificar a esta cuenta en analítica: solo si el servidor lo
  /// dijo explícitamente (`analytics_anonymous == false`) y no es un menor.
  bool get canIdentifyInAnalytics =>
      analyticsAnonymous == false &&
      !isSupervisedTeen &&
      (principal?.kind ?? PrincipalKind.user) == PrincipalKind.user;

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        avatar,
        birthday,
        metadata,
        authorization,
        lastSignInAt,
        createdAt,
        postRegisterComplete,
        legalAcceptancePending,
        actingFor,
        family,
        principal,
        familyFeatures,
        analyticsAnonymous,
        serverMode,
      ];
}
