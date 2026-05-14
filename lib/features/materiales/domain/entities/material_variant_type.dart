/// Tipo de variante de un producto de materiales.
enum MaterialVariantType {
  talla,
  color,
}

/// Extensiones de utilidad para [MaterialVariantType].
extension MaterialVariantTypeX on MaterialVariantType {
  static MaterialVariantType fromString(String value) {
    switch (value) {
      case 'color':
        return MaterialVariantType.color;
      default:
        return MaterialVariantType.talla;
    }
  }

  String toApiString() {
    switch (this) {
      case MaterialVariantType.talla:
        return 'talla';
      case MaterialVariantType.color:
        return 'color';
    }
  }
}
