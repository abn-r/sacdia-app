/// Tier de categoría de premiación en el sistema de rankings.
///
/// Espeja el enum `AwardCategoryTier` del backend.
/// Excluye PLATINUM (no existe en el dominio de rankings — solo en logros).
/// [unknown] se usa como fallback seguro para valores inesperados o null.
enum AwardTier {
  bronze,
  silver,
  gold,
  diamond,
  unknown;

  /// Parsea un valor raw del backend (e.g. 'BRONZE', 'GOLD') al enum.
  /// Retorna [AwardTier.unknown] si el valor es null o no reconocido.
  static AwardTier fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'BRONZE':
        return AwardTier.bronze;
      case 'SILVER':
        return AwardTier.silver;
      case 'GOLD':
        return AwardTier.gold;
      case 'DIAMOND':
        return AwardTier.diamond;
      default:
        return AwardTier.unknown;
    }
  }
}
