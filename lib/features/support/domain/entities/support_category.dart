/// Categorías de reporte soportadas por el backend.
///
/// IMPORTANTE: Los `wireValue` deben coincidir exactamente con el enum del
/// backend (`sacdia-backend/src/support/dto/create-support-report.dto.ts` →
/// `SupportCategory`). Al agregar un valor aquí, hay que agregarlo también
/// allá y en el CHECK constraint de la tabla `support_reports`.
enum SupportCategory {
  bug('bug'),
  featureRequest('feature_request'),
  account('account'),
  dataIssue('data_issue'),
  performance('performance'),
  other('other');

  final String wireValue;
  const SupportCategory(this.wireValue);

  /// Clave i18n usada para el label del picker (concatenar con
  /// `'support.category.'`). Mantener sincronizado con las traducciones.
  String get i18nKey => 'support.category.${name.toLowerCase()}';

  static SupportCategory fromWire(String value) {
    return SupportCategory.values.firstWhere(
      (c) => c.wireValue == value,
      orElse: () => SupportCategory.other,
    );
  }
}
