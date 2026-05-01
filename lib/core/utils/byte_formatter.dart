/// Humanizes a raw byte count into a localized-friendly short string.
///
/// Uses binary units (1024) — matches what users see in iOS/Android storage
/// settings. Keeps 1 decimal place for MB/GB, 0 decimals for KB/B.
///
/// Examples:
///   formatBytes(0)         → '0 B'
///   formatBytes(512)       → '512 B'
///   formatBytes(2048)      → '2 KB'
///   formatBytes(5_500_000) → '5.2 MB'
///   formatBytes(2_147_483_648) → '2.0 GB'
///
/// The output is unit-suffixed in English-ish notation (B/KB/MB/GB). This is
/// intentional: storage units are universally recognized across the app's
/// 4 supported locales (es / pt-BR / en / fr), so we avoid translating them.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';

  const kb = 1024;
  const mb = 1024 * 1024;
  const gb = 1024 * 1024 * 1024;

  if (bytes < mb) {
    // KB — whole number, enough precision for cache-size UX.
    return '${(bytes / kb).round()} KB';
  }
  if (bytes < gb) {
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }
  return '${(bytes / gb).toStringAsFixed(2)} GB';
}
