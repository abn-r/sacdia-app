import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/badge_grid/sac_badge_tint.dart';
import 'package:sacdia_app/core/widgets/sac_sheet_header.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_state_panel.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_style.dart';

import '../../domain/entities/achievement.dart';
import '../../domain/entities/user_achievement.dart';
import '../../domain/repositories/achievements_repository.dart';
import '../providers/achievements_providers.dart';
import '../utils/achievement_dates.dart';
import '../utils/achievement_progress_unit.dart';
import '../widgets/achievement_art.dart';
import '../widgets/achievement_badge.dart';
import '../widgets/achievement_detail_parts.dart';
import '../widgets/achievement_hero_glow.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

const double _kHeroSize = 252;

/// Detail sheet: the badge itself (grey until obtained), name, tier and
/// points, the description and ONE block that says where the user stands:
/// progress, the date it was obtained, or the secret hint.
///
/// It follows [userAchievementsProvider], so progress that changes while the
/// sheet is open rolls the number and grows the bar.
class AchievementDetailSheet extends ConsumerStatefulWidget {
  final AchievementWithProgress achievementWithProgress;

  const AchievementDetailSheet({
    super.key,
    required this.achievementWithProgress,
  });

  @override
  ConsumerState<AchievementDetailSheet> createState() =>
      _AchievementDetailSheetState();
}

class _AchievementDetailSheetState extends ConsumerState<AchievementDetailSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: SacMotion.modal);
    _fade = CurvedAnimation(parent: _enter, curve: SacMotion.easeOut);
    _scale = Tween<double>(begin: SacMotion.enterScale, end: 1).animate(
      CurvedAnimation(parent: _enter, curve: SacMotion.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SacMotion.reduceMotionOf(context)) {
      _enter.value = 1;
    } else if (!_enter.isAnimating && _enter.value == 0) {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  /// The freshest copy of the achievement the sheet was opened for.
  AchievementWithProgress _current() {
    final opened = widget.achievementWithProgress;
    final response = ref.watch(userAchievementsProvider).value;
    if (response == null) return opened;
    final id = opened.achievement.achievementId;
    for (final group in response.categories) {
      for (final item in group.achievements) {
        if (item.achievement.achievementId == id) return item;
      }
    }
    return opened;
  }

  @override
  Widget build(BuildContext context) {
    final current = _current();
    final achievement = current.achievement;
    final userAchievement = current.userAchievement;

    final isCompleted = userAchievement?.isCompleted ?? false;
    final isSecret = achievement.secret && !isCompleted;
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final prerequisite = _prerequisiteOf(achievement);

    final description = isSecret
        ? 'achievements.views.detail_secret_hint'.tr()
        : achievement.description;

    // The sheet is as tall as what it shows: a one-off achievement is a short
    // card, not a screen of white. Long content (a collection) scrolls once it
    // reaches the cap.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXL)),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXL)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SacSheetGrabber(),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + bottomInset),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          ScaleTransition(
                            scale: _scale,
                            child: _BadgeHero(
                              achievement: achievement,
                              isObtained: isCompleted,
                              isSecret: isSecret,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isSecret
                                ? 'achievements.views.secret_name'.tr()
                                : achievement.name,
                            style: TextStyle(
                              fontSize: SacFontSize.headlineLarge,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              height: 1.15,
                              color: c.text,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (achievement.tier != AchievementTier.unknown)
                                AchievementDetailChip(
                                  leading: AchievementTierDot(
                                    color:
                                        achievementTierColor(achievement.tier),
                                  ),
                                  label: achievement.tier.displayName,
                                  foreground: c.textSecondary,
                                  background: c.surfaceVariant,
                                ),
                              if (!isSecret) ...[
                                AchievementDetailChip(
                                  label: 'achievements.views.detail_points'
                                      .tr(namedArgs: {
                                    'points': '${achievement.points}',
                                  }),
                                  foreground: accent,
                                  background: accent.withValues(alpha: 0.12),
                                ),
                                if (achievement.repeatable)
                                  AchievementDetailChip(
                                    leading: HugeIcon(
                                      icon: HugeIcons.strokeRoundedRefresh,
                                      size: 13,
                                      color: c.textSecondary,
                                    ),
                                    label:
                                        'achievements.views.detail_repeatable'
                                            .tr(),
                                    foreground: c.textSecondary,
                                    background: c.surfaceVariant,
                                  ),
                              ],
                            ],
                          ),
                          if (description != null &&
                              description.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                description,
                                style: TextStyle(
                                  fontSize: SacFontSize.titleMedium,
                                  height: 1.45,
                                  color: c.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          if (!isSecret) ...[
                            const SizedBox(height: 20),
                            _StatusBlock(
                              achievement: achievement,
                              userAchievement: userAchievement,
                              prerequisite: prerequisite,
                            ),
                            if (achievement.type ==
                                AchievementType.collection) ...[
                              const SizedBox(height: 12),
                              AchievementCollectionContent(
                                achievement: achievement,
                                userAchievement: userAchievement,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The prerequisite of [achievement] as the list knows it; null when it has
  /// none. An id the list does not have yet comes back as
  /// [_Prerequisite.unknown].
  _Prerequisite? _prerequisiteOf(Achievement achievement) {
    final id = achievement.prerequisiteId;
    if (id == null) return null;
    final response = ref.watch(userAchievementsProvider).value;
    for (final group in response?.categories ?? const []) {
      for (final item in group.achievements) {
        if (item.achievement.achievementId == id) {
          return _Prerequisite(
            name: item.achievement.name,
            isCompleted: item.userAchievement?.isCompleted ?? false,
          );
        }
      }
    }
    return _Prerequisite.unknown;
  }
}

/// What the sheet needs to know about the achievement that unlocks this one.
class _Prerequisite {
  const _Prerequisite({required this.name, required this.isCompleted});

  static const unknown = _Prerequisite(name: null, isCompleted: false);

  /// Null when the list does not have it.
  final String? name;
  final bool isCompleted;
}

// -- Badge hero ---------------------------------------------------------------

/// The achievement's own badge: grey while it is not obtained, full colour
/// (with the platinum/diamond shimmer) once it is. A secret one that is not
/// obtained shows its own drawing, the same as in the grid.
class _BadgeHero extends StatelessWidget {
  final Achievement achievement;
  final bool isObtained;
  final bool isSecret;

  const _BadgeHero({
    required this.achievement,
    required this.isObtained,
    required this.isSecret,
  });

  @override
  Widget build(BuildContext context) {
    if (isSecret) return const SecretBadgeArt(height: _kHeroSize);

    if (isObtained) {
      final tier = achievement.tier;
      return AchievementHeroGlow(
        color: tier == AchievementTier.unknown
            ? SacAccent.of(context).color
            : achievementTierColor(tier),
        size: _kHeroSize,
        child: AchievementBadge(
          badgeImageUrl: achievement.badgeImageUrl,
          tier: tier,
          visualState: AchievementVisualState.unlocked,
          size: _kHeroSize,
        ),
      );
    }

    return SacBadgeTint.tone(
      tone: SacBadgeTone.muted,
      child: AchievementArt(
        imageUrl: achievement.badgeImageUrl,
        name: achievement.name,
        height: _kHeroSize,
        width: _kHeroSize,
        fallbackColor: SacAccent.of(context).color,
      ),
    );
  }
}

// -- Status block -------------------------------------------------------------

/// Where the user stands, always ONE block: obtained, locked behind another
/// achievement, the progress block, or "not obtained yet".
class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.achievement,
    required this.userAchievement,
    required this.prerequisite,
  });

  final Achievement achievement;
  final UserAchievement? userAchievement;
  final _Prerequisite? prerequisite;

  @override
  Widget build(BuildContext context) {
    final user = userAchievement;
    if (user != null && user.isCompleted) {
      final completedAt = user.completedAt;
      final title = completedAt == null
          ? 'achievements.views.obtained'.tr()
          : 'achievements.views.detail_obtained_on'.tr(
              namedArgs: {'date': achievementLongDate(completedAt)},
            );
      final times = achievement.repeatable && user.timesCompleted > 0
          ? '${'achievements.views.detail_times_completed'.tr()} · '
              '${user.timesCompleted}'
          : null;
      return _panel(
        SacStatusStyle.of(context, SacStatusKind.validated, label: title),
        title,
        times,
      );
    }

    final lock = prerequisite;
    if (lock != null && !lock.isCompleted) {
      final title = 'achievements.views.detail_locked'.tr();
      final name = lock.name;
      return _panel(
        SacStatusStyle.of(
          context,
          SacStatusKind.pending,
          label: title,
          icon: HugeIcons.strokeRoundedSquareLock02,
        ),
        title,
        name == null
            ? 'achievements.views.detail_locked_generic'.tr()
            : 'achievements.views.detail_locked_requires'
                .tr(namedArgs: {'name': name}),
      );
    }

    final hasRecord = user != null && user.progressTarget > 0;
    final target = hasRecord
        ? user.progressTarget
        : achievementCriteriaTarget(achievement);
    // A one-off achievement (target 1) is yes or no: "0 de 1" says nothing.
    if (target <= 1) {
      final title = 'achievements.views.detail_not_obtained'.tr();
      return _panel(
        SacStatusStyle.of(
          context,
          SacStatusKind.pending,
          label: title,
          icon: HugeIcons.strokeRoundedInformationCircle,
        ),
        title,
        null,
      );
    }

    final current = user?.progressValue ?? 0;
    final isStreak = achievement.type == AchievementType.streak;

    return AchievementProgressBlock(
      label: isStreak
          ? 'achievements.views.detail_streak'.tr()
          : 'achievements.views.detail_progress'.tr(),
      current: current,
      target: target,
      unit: achievementUnitLabel(achievement, target),
    );
  }

  Widget _panel(SacStatusStyle style, String title, String? message) {
    return SizedBox(
      width: double.infinity,
      child: SacStatePanel(style: style, title: title, message: message),
    );
  }
}
