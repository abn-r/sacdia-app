/// Cómo ingresa una cuenta a la app, decidido por el servidor
/// (`onboarding_mode` en el login, `/auth/me` y el estado del post-registro).
///
/// No confundir con `AccountMode` (tipo de principal: adulto, adolescente...).
/// La app nunca lo calcula a partir de roles ni de clubes.
enum OnboardingMode {
  /// Flujo normal de club (3 pasos). Es el valor por defecto.
  club('club'),

  /// Cuenta sin club por diseño (pastor, coordinación): 2 pasos.
  clubExempt('club_exempt'),

  /// Cuenta que solo usa el panel web: no pasa por el post-registro.
  panelOnly('panel_only');

  const OnboardingMode(this.wireValue);

  /// Valor que viaja en el JSON del servidor.
  final String wireValue;

  /// Un valor ausente o desconocido es [club] (servidor anterior al campo).
  static OnboardingMode parse(Object? raw) {
    if (raw is! String) return OnboardingMode.club;
    final normalized = raw.trim().toLowerCase();
    for (final mode in OnboardingMode.values) {
      if (mode.wireValue == normalized) return mode;
    }
    return OnboardingMode.club;
  }
}
