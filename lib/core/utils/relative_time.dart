import 'package:easy_localization/easy_localization.dart';

/// Formats a [DateTime] as a relative-time string using the active locale
/// (via `tr()` from easy_localization).
///
/// Buckets (monotonic):
///   - < 60s           → `settings.relative_time_just_now`
///   - < 60 min        → `settings.relative_time_min_ago` (plural-aware via easy_localization)
///   - < 24 h          → `settings.relative_time_hour_ago`
///   - otherwise       → `settings.relative_time_day_ago`
///
/// The translation keys receive an `n` argument (the whole-number value for
/// the bucket). Locale plural rules are handled inside the easy_localization
/// `plural()` helper — the caller stays ignorant of whether the locale needs
/// "1 minuto" vs "2 minutos" vs "3 minut" etc.
///
/// If [when] is null the helper returns the `settings.last_sync_never` key —
/// callers using this for "last sync" timestamps should pass null when the
/// value is missing instead of branching before calling.
String formatRelativeTime(DateTime? when, {DateTime? now}) {
  if (when == null) {
    return 'settings.last_sync_never'.tr();
  }
  final ref = now ?? DateTime.now();
  final diff = ref.difference(when);

  // Future timestamps or negative deltas → treat as "just now" to avoid
  // showing "-3 min ago" if the device clock skews.
  if (diff.inSeconds < 60) {
    return 'settings.relative_time_just_now'.tr();
  }

  if (diff.inMinutes < 60) {
    return 'settings.relative_time_min_ago'.plural(diff.inMinutes);
  }

  if (diff.inHours < 24) {
    return 'settings.relative_time_hour_ago'.plural(diff.inHours);
  }

  return 'settings.relative_time_day_ago'.plural(diff.inDays);
}
