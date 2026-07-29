/// Local SVG medals for annual ranking tiers.
///
/// Add matching files under `assets/svg/`. Missing assets fall back to the
/// tinted award icon. Remote tier `imageUrl` wins when present.
const Map<String, String> kRankingTierLocalSvgAssets = {
  'bronce': 'assets/svg/fiel_bronce.svg',
  'bronze': 'assets/svg/fiel_bronce.svg',
  'plata': 'assets/svg/fiel_plata.svg',
  'silver': 'assets/svg/fiel_plata.svg',
  'oro': 'assets/svg/fiel_oro.svg',
  'gold': 'assets/svg/fiel_oro.svg',
  'diamante': 'assets/svg/fiel_diamante.svg',
  'diamond': 'assets/svg/fiel_diamante.svg',
};

/// Returns the bundled SVG path for [slug], or null when unknown.
String? rankingTierLocalSvgAsset(String? slug) {
  if (slug == null || slug.isEmpty) return null;
  return kRankingTierLocalSvgAssets[slug.toLowerCase().trim()];
}
