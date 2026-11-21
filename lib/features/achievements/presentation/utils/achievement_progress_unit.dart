import 'package:easy_localization/easy_localization.dart';

import '../../domain/entities/achievement.dart';

/// Period a streak is counted in (`criteria.streak_unit`, set by the backend:
/// "day", "week" or "month").
enum AchievementStreakUnit {
  day('achievements.views.unit_day'),
  week('achievements.views.unit_week'),
  month('achievements.views.unit_month');

  const AchievementStreakUnit(this.translationKey);

  /// Plural translation: one / other forms.
  final String translationKey;

  static AchievementStreakUnit? tryParse(Object? raw) {
    if (raw is! String) return null;
    switch (raw.trim().toLowerCase()) {
      case 'day':
      case 'days':
        return AchievementStreakUnit.day;
      case 'week':
      case 'weeks':
        return AchievementStreakUnit.week;
      case 'month':
      case 'months':
        return AchievementStreakUnit.month;
    }
    return null;
  }
}

/// The streak period of [achievement], or null when the criteria do not say
/// (then no unit is shown: a wrong one is worse than none).
AchievementStreakUnit? achievementStreakUnit(Achievement achievement) =>
    AchievementStreakUnit.tryParse(achievement.criteria['streak_unit']);

/// Unit to print after "1 de 4", agreeing in number with [count] ("semana",
/// "semanas"); null when the achievement has no known period.
String? achievementUnitLabel(Achievement achievement, int count) {
  final unit = achievementStreakUnit(achievement);
  if (unit == null) return null;
  return unit.translationKey.plural(count);
}

/// Target of the achievement from its criteria, for the case the user has no
/// progress record yet.
int achievementCriteriaTarget(Achievement achievement) {
  final target = achievement.criteria['target'];
  return target is num ? target.toInt() : 0;
}
