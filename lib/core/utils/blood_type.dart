/// Tipos de sangre soportados por el backend (`enum blood_type` en Prisma).
///
/// - [display] es el valor compacto visible en formularios (`'A+'`, `'O-'`).
/// - [apiKey] es la key TypeScript del enum que el backend espera en PATCH
///   `/users/:id` con campo `blood` (validado por `@IsEnum(blood_type)`).
///
/// El backend puede devolver cualquiera de los dos formatos según endpoint o
/// mutación (`'O+'` o `'O_POSITIVE'`). Las pantallas que necesitan texto largo
/// deben usar [localizedDisplayFor].
enum BloodType {
  aPos('A+', 'A_POSITIVE', 'A', _Rh.positive),
  aNeg('A-', 'A_NEGATIVE', 'A', _Rh.negative),
  bPos('B+', 'B_POSITIVE', 'B', _Rh.positive),
  bNeg('B-', 'B_NEGATIVE', 'B', _Rh.negative),
  abPos('AB+', 'AB_POSITIVE', 'AB', _Rh.positive),
  abNeg('AB-', 'AB_NEGATIVE', 'AB', _Rh.negative),
  oPos('O+', 'O_POSITIVE', 'O', _Rh.positive),
  oNeg('O-', 'O_NEGATIVE', 'O', _Rh.negative);

  const BloodType(this.display, this.apiKey, this.group, this._rh);

  final String display;
  final String apiKey;
  final String group;
  final _Rh _rh;

  static BloodType? fromDisplay(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.trim().toUpperCase();
    for (final type in BloodType.values) {
      if (type.display.toUpperCase() == normalized ||
          type.apiKey.toUpperCase() == normalized) {
        return type;
      }
    }
    return null;
  }

  static String? displayFor(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return fromDisplay(value)?.display ?? value.trim();
  }

  static String? localizedDisplayFor(
    String? value, {
    required String languageCode,
  }) {
    if (value == null || value.trim().isEmpty) return null;

    final normalized = value.trim();
    final type = fromDisplay(normalized);
    if (type == null) return normalized;

    return '${type.group} ${type._rh.localized(languageCode)}';
  }
}

enum _Rh {
  positive,
  negative;

  String localized(String languageCode) {
    final language = languageCode.trim().toLowerCase();
    return switch (language) {
      'en' => this == _Rh.positive ? 'positive' : 'negative',
      'fr' => this == _Rh.positive ? 'positif' : 'négatif',
      'pt' || 'pt-br' => this == _Rh.positive ? 'positivo' : 'negativo',
      _ => this == _Rh.positive ? 'positivo' : 'negativo',
    };
  }
}
