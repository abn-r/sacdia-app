/// Asset paths for duotone category illustrations.
///
/// Resolve by [categoryName] (stable semantic key). IDs are not a contract —
/// see [honor_category_palette.dart].
class HonorCategoryIllustration {
  HonorCategoryIllustration._();

  static const String _base =
      'assets/illustrations/honors/categories';

  static const Map<String, String> _byName = {
    'ADRA': '$_base/adra.svg',
    'Actividades Agropecuarias': '$_base/agropecuarias.svg',
    'Ciencias de la Salud': '$_base/ciencias_salud.svg',
    'Salud y Ciencia': '$_base/ciencias_salud.svg',
    'Artes Domésticas': '$_base/domesticas.svg',
    'Artes y Actividades Manuales': '$_base/habilidades_manuales.svg',
    'Crecimiento Espiritual, Actividades Misioneras y Herencia':
        '$_base/misioneras.svg',
    'Estudio de la Naturaleza': '$_base/naturaleza.svg',
    'Actividades Vocacionales': '$_base/vocacionales.svg',
    'Artes Vocacionales': '$_base/vocacionales.svg',
    'Actividades Recreativas': '$_base/recreativas.svg',
    'Actividades Recreacionales': '$_base/recreativas.svg',
    'Doctrinales': '$_base/doctrinales.svg',
  };

  /// Returns the SVG asset path for [categoryName], or null if unknown.
  static String? assetForName(String? categoryName) {
    if (categoryName == null || categoryName.isEmpty) return null;
    return _byName[categoryName];
  }

  /// All known illustration asset paths (for precache / tests).
  static List<String> get allAssets =>
      _byName.values.toSet().toList(growable: false);
}
