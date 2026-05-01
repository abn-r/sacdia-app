/// Estado de configuración biométrica del usuario.
///
/// Inmutable. Persistido vía SharedPreferences:
/// - [enabled]  → `AppConstants.biometricEnabledKey`    (bool)
/// - [enrolledAt] → `AppConstants.biometricEnrolledAtKey` (ISO-8601 string)
///
/// NUNCA guardamos datos biométricos — solo el flag de opt-in.
class BiometricSettings {
  final bool enabled;
  final DateTime? enrolledAt;

  const BiometricSettings({
    required this.enabled,
    this.enrolledAt,
  });

  /// Estado inicial por defecto: OFF (opt-in explícito).
  const BiometricSettings.disabled()
      : enabled = false,
        enrolledAt = null;

  BiometricSettings copyWith({
    bool? enabled,
    DateTime? enrolledAt,
    bool clearEnrolledAt = false,
  }) {
    return BiometricSettings(
      enabled: enabled ?? this.enabled,
      enrolledAt: clearEnrolledAt ? null : (enrolledAt ?? this.enrolledAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiometricSettings &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          enrolledAt == other.enrolledAt;

  @override
  int get hashCode => Object.hash(enabled, enrolledAt);
}
