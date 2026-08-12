/// Builds localized share text for an unlocked achievement.
///
/// [template] must already be localized (caller runs `.tr()`). Placeholders:
/// `{name}`, `{tier}`, `{points}`, optional `{completedOn}`.
/// Never emits the literal string `null`.
String buildAchievementShareText({
  required String template,
  required String name,
  required String tier,
  required int points,
  String? completedOn,
}) {
  final safeName = name;
  final safeTier = tier;
  final safeDate =
      (completedOn == null || completedOn.isEmpty) ? '' : completedOn;

  return template
      .replaceAll('{name}', safeName)
      .replaceAll('{tier}', safeTier)
      .replaceAll('{points}', '$points')
      .replaceAll('{completedOn}', safeDate)
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r'\s+—\s*$'), '')
      .replaceAll(RegExp(r'\s+-\s*$'), '')
      .trim();
}
