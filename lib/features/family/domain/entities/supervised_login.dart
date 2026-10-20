import 'package:equatable/equatable.dart';

/// Cómo inicia sesión el menor.
enum SupervisedLoginMethod {
  /// Usuario generado por el servidor (sin correo).
  handle,

  /// Su propio correo.
  email;

  static SupervisedLoginMethod parse(Object? raw) =>
      raw == 'email' ? email : handle;

  String get wire => this == email ? 'email' : 'handle';
}

/// Quién fijó la contraseña vigente.
enum PasswordSetBy {
  guardian,
  self;

  static PasswordSetBy? parse(Object? raw) => switch (raw) {
        'guardian' => guardian,
        'self' => self,
        _ => null,
      };
}

/// Acceso propio de un menor (`supervised_login`).
class SupervisedLoginInfo extends Equatable {
  final SupervisedLoginMethod method;

  /// Solo con `method == handle`. Lo ven los tutores verificados; nunca va a
  /// listas, buscadores ni notificaciones.
  final String? loginHandle;
  final String? email;

  /// `guardian_enabled` o `self_registered` (solo en el GET de acceso).
  final String? origin;
  final DateTime? enabledAt;
  final DateTime? disabledAt;
  final String? disabledReason;
  final PasswordSetBy? passwordSetBy;

  const SupervisedLoginInfo({
    required this.method,
    this.loginHandle,
    this.email,
    this.origin,
    this.enabledAt,
    this.disabledAt,
    this.disabledReason,
    this.passwordSetBy,
  });

  bool get isDisabled => disabledAt != null;

  /// El tutor puede reactivarlo si él lo activó o lo desactivó un tutor (no si
  /// se cerró por la mayoría de edad o por la purga de 90 días).
  bool get canBeReactivated =>
      isDisabled &&
      disabledReason != 'age_majority' &&
      disabledReason != 'unlinked_purged';

  @override
  List<Object?> get props => [
        method,
        loginHandle,
        email,
        origin,
        enabledAt,
        disabledAt,
        disabledReason,
        passwordSetBy,
      ];
}

/// Por qué un menor no puede tener acceso propio ahora
/// (`ineligible_reason` de `GET .../supervised-login`).
enum IneligibleReason {
  ageBelowMin,
  ageOverMajority,
  consentNotVerified,
  featureDisabled,
  custodianOnly,
  unknown;

  static IneligibleReason? parse(Object? raw) => switch (raw) {
        null => null,
        'age_below_min' => ageBelowMin,
        'age_over_majority' => ageOverMajority,
        'consent_not_verified' => consentNotVerified,
        'feature_disabled' => featureDisabled,
        'custodian_only' => custodianOnly,
        _ => unknown,
      };
}

/// `GET .../dependents/:id/supervised-login`.
class SupervisedLoginStatus extends Equatable {
  final bool eligible;
  final IneligibleReason? ineligibleReason;
  final SupervisedLoginInfo? supervisedLogin;

  const SupervisedLoginStatus({
    required this.eligible,
    this.ineligibleReason,
    this.supervisedLogin,
  });

  @override
  List<Object?> get props => [eligible, ineligibleReason, supervisedLogin];
}

/// `201` de activar el acceso: el acceso creado y los teléfonos desvinculados.
class EnabledSupervisedLogin extends Equatable {
  final SupervisedLoginInfo supervisedLogin;
  final int devicesRevoked;

  const EnabledSupervisedLogin({
    required this.supervisedLogin,
    this.devicesRevoked = 0,
  });

  @override
  List<Object?> get props => [supervisedLogin, devicesRevoked];
}

/// `200` de restablecer la contraseña.
class PasswordResetResult extends Equatable {
  final int sessionsRevoked;

  const PasswordResetResult({this.sessionsRevoked = 0});

  @override
  List<Object?> get props => [sessionsRevoked];
}
