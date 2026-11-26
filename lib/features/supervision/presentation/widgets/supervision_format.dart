import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

String? _localeTag(BuildContext context) =>
    Localizations.maybeLocaleOf(context)?.toLanguageTag();

/// Whole number with the locale's grouping ("1,240").
String supervisionCount(BuildContext context, num value) =>
    intl.NumberFormat.decimalPattern(_localeTag(context)).format(value.round());

/// Points: whole when they are whole, one decimal otherwise.
String supervisionPoints(BuildContext context, double value) {
  final whole = value == value.roundToDouble();
  final format = intl.NumberFormat.decimalPattern(_localeTag(context))
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = whole ? 0 : 1;
  return format.format(value);
}

/// Percentage of a 0-100 value. It never rounds up to 100: "100%" means
/// nothing is missing.
String supervisionPercent(double value) {
  final clamped = value.clamp(0, 100);
  final shown = clamped >= 100 ? 100 : clamped.floor();
  return '$shown%';
}

/// The place of an IANA zone id, as people say it: "America/Mexico_City"
/// reads "Mexico City", "America/Argentina/Buenos_Aires" reads "Buenos
/// Aires". An id with no region ("UTC") is kept as it comes.
String supervisionZoneLabel(String zoneId) {
  final id = zoneId.trim();
  final place = id.substring(id.lastIndexOf('/') + 1);
  return place.replaceAll('_', ' ').trim();
}

/// Month name in the app language ("octubre").
String supervisionMonthName(BuildContext context, int month) =>
    intl.DateFormat.MMMM(_localeTag(context)).format(DateTime(2000, month));

/// Month and year in the app language ("octubre de 2026").
String supervisionMonthYear(BuildContext context, int year, int month) =>
    intl.DateFormat.yMMMM(_localeTag(context)).format(DateTime(year, month));

/// Day, month and year in the app language ("12 nov 2026").
String supervisionShortDate(BuildContext context, DateTime date) =>
    intl.DateFormat.yMMMd(_localeTag(context)).format(date);

/// Date and time in the app language ("12 nov 2026 21:00").
String supervisionDateTime(BuildContext context, DateTime moment) =>
    intl.DateFormat.yMMMd(_localeTag(context)).add_Hm().format(moment);
