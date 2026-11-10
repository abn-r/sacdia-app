import 'package:easy_localization/easy_localization.dart';

import '../../domain/entities/join_request.dart';

/// Name shown for a request: the full name, else the email, else a fallback
/// (some requests come with an empty name).
String joinRequestDisplayName(JoinRequest request) {
  final fullName = request.fullName.trim();
  if (fullName.isNotEmpty) return fullName;
  final email = request.email?.trim() ?? '';
  if (email.isNotEmpty) return email;
  return 'members.requests.unnamed'.tr();
}

/// Name used to draw the avatar initials; empty when the request has no name.
String joinRequestAvatarName(JoinRequest request) {
  final fullName = request.fullName.trim();
  if (fullName.isNotEmpty) return fullName;
  return request.email?.trim() ?? '';
}

/// "today", "1 day ago", "N days ago" counted in local calendar days.
/// `null` when the request has no date.
String? joinRequestRelativeDate(DateTime? requestedAt, {DateTime? now}) {
  if (requestedAt == null) return null;
  final today = now ?? DateTime.now();
  final local = requestedAt.toLocal();
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;
  if (days <= 0) return 'members.requests.today'.tr();
  return 'settings.relative_time_day_ago'.plural(days);
}

/// Absolute date, same format the old request card used.
String? joinRequestAbsoluteDate(DateTime? requestedAt) => requestedAt == null
    ? null
    : DateFormat('dd MMM yyyy').format(requestedAt.toLocal());
