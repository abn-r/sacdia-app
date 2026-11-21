import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/badge_grid/sac_badge_card.dart';
import 'package:sacdia_app/core/widgets/badge_grid/sac_badge_tint.dart';

import '../../domain/entities/user_achievement.dart';
import '../../domain/repositories/achievements_repository.dart';
import '../utils/achievement_dates.dart';
import 'achievement_art.dart';
import 'achievement_shine.dart';

/// Art height of an achievement card: 20% over the shared default, the
/// badges are the point of this grid.
const double kAchievementGridArtHeight = SacBadgeCard.defaultArtHeight * 1.2;

/// An obtained badge in the grid catches the light this often: half as often
/// as the detail, the grid is where the user spends time.
const Duration kAchievementGridShinePeriod = Duration(seconds: 10);

/// Card of the achievements grid. Every card has the same look; only the art
/// and the meta line say the state:
///
/// - obtained: badge in colour and a check with the date;
/// - in progress: grey badge, a bar in the app accent and "6 de 10";
/// - not started: grey badge, no meta;
/// - secret and not obtained: its own drawing and the name "Logro secreto".
class AchievementGridCard extends StatelessWidget {
  const AchievementGridCard({
    super.key,
    required this.achievementWithProgress,
    this.onTap,
  });

  final AchievementWithProgress achievementWithProgress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final achievement = achievementWithProgress.achievement;
    final user = achievementWithProgress.userAchievement;

    final isCompleted = user?.isCompleted ?? false;
    final isSecret = achievement.secret && !isCompleted;
    final state = user?.visualState ?? AchievementVisualState.locked;
    final isObtained = state == AchievementVisualState.unlocked;

    final name =
        isSecret ? 'achievements.views.secret_name'.tr() : achievement.name;

    Widget art;
    if (isSecret) {
      art = const SecretBadgeArt(height: kAchievementGridArtHeight);
    } else {
      art = AchievementArt(
        imageUrl: achievement.badgeImageUrl,
        name: achievement.name,
        height: kAchievementGridArtHeight,
        fallbackColor:
            isObtained ? context.sac.success : SacAccent.of(context).color,
      );
      if (isObtained) {
        art = AchievementShine(
          period: kAchievementGridShinePeriod,
          initialDelay: const Duration(seconds: 2),
          child: art,
        );
      }
    }

    return SacBadgeCard(
      name: name,
      art: art,
      tone: isObtained || isSecret ? SacBadgeTone.color : SacBadgeTone.muted,
      nameEmphasized: isObtained,
      meta: isSecret ? const SacBadgeMeta.none() : _metaFor(state, user),
      artHeight: kAchievementGridArtHeight,
      onTap: onTap,
    );
  }

  SacBadgeMeta _metaFor(AchievementVisualState state, UserAchievement? user) {
    switch (state) {
      case AchievementVisualState.unlocked:
        final completedAt = user?.completedAt;
        return SacBadgeMeta.obtained(
          completedAt == null
              ? 'achievements.views.obtained'.tr()
              : achievementShortDate(completedAt),
        );
      case AchievementVisualState.inProgress:
        if (user == null || user.progressTarget <= 0) {
          return const SacBadgeMeta.none();
        }
        return SacBadgeMeta.progress(
          fraction: user.progressPercentage,
          label: 'achievements.views.progress_fraction'.tr(
            namedArgs: {
              'current': '${user.progressValue}',
              'total': '${user.progressTarget}',
            },
          ),
        );
      case AchievementVisualState.locked:
        return const SacBadgeMeta.none();
    }
  }
}
