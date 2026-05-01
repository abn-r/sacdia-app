/// Preferencias de accesibilidad persistidas localmente (MVP: SharedPreferences).
///
/// Sigue el mismo patrón que [ThemeNotifier] — el estado es inmutable y se
/// reconstruye mediante [copyWith].
library;

/// Presets de tamaño de texto.
///
/// - [system]: respeta el factor del sistema operativo (no aplica override).
/// - [normal]: factor 1.0 (baseline de la app).
/// - [large]: factor 1.3.
/// - [extraLarge]: factor 1.6.
enum TextSizeOption {
  system,
  normal,
  large,
  extraLarge;

  /// Factor de escalado de texto asociado al preset.
  ///
  /// `null` indica que se debe respetar el [TextScaler] del sistema.
  double? get factor {
    switch (this) {
      case TextSizeOption.system:
        return null;
      case TextSizeOption.normal:
        return 1.0;
      case TextSizeOption.large:
        return 1.3;
      case TextSizeOption.extraLarge:
        return 1.6;
    }
  }

  /// Clave estable para serializar en SharedPreferences.
  String get storageValue {
    switch (this) {
      case TextSizeOption.system:
        return 'system';
      case TextSizeOption.normal:
        return 'normal';
      case TextSizeOption.large:
        return 'large';
      case TextSizeOption.extraLarge:
        return 'extra_large';
    }
  }

  static TextSizeOption fromStorage(String? value) {
    switch (value) {
      case 'system':
        return TextSizeOption.system;
      case 'normal':
        return TextSizeOption.normal;
      case 'large':
        return TextSizeOption.large;
      case 'extra_large':
        return TextSizeOption.extraLarge;
      default:
        return TextSizeOption.system;
    }
  }
}

/// Estado inmutable de las preferencias de accesibilidad.
class AccessibilitySettings {
  final TextSizeOption textSize;
  final bool highContrast;
  final bool reduceMotion;

  const AccessibilitySettings({
    this.textSize = TextSizeOption.system,
    this.highContrast = false,
    this.reduceMotion = false,
  });

  /// Factor efectivo para [TextScaler.linear]. `null` significa "respetar el
  /// [TextScaler] actual del [MediaQuery]" (no aplicar override).
  double? get textScaleFactor => textSize.factor;

  AccessibilitySettings copyWith({
    TextSizeOption? textSize,
    bool? highContrast,
    bool? reduceMotion,
  }) {
    return AccessibilitySettings(
      textSize: textSize ?? this.textSize,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessibilitySettings &&
          other.textSize == textSize &&
          other.highContrast == highContrast &&
          other.reduceMotion == reduceMotion;

  @override
  int get hashCode => Object.hash(textSize, highContrast, reduceMotion);
}
