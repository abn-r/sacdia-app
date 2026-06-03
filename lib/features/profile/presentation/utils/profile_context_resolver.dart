/// Resolves the club type that the profile should render for context-sensitive
/// UI such as progressive class logos.
///
/// The active authorization grant is the source of truth after a section
/// switch. Profile data can lag until a manual refresh, so it is only used as a
/// fallback when no active club type is available.
String? resolveProfileClubType({
  required String? profileClubType,
  required String? activeClubTypeName,
}) {
  final active = activeClubTypeName?.trim();
  if (active != null && active.isNotEmpty) return active;

  final fallback = profileClubType?.trim();
  if (fallback != null && fallback.isNotEmpty) return fallback;

  return null;
}
