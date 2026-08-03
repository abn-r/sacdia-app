import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/achievement.dart';
import '../../domain/entities/user_achievement.dart';
import '../../domain/repositories/achievements_repository.dart';
import '../widgets/achievement_badge.dart';
import '../widgets/achievement_progress_bar.dart';

/// Detail sheet v2 — badge hero, status meta, inset groups, SacMotion enter.
class AchievementDetailSheet extends StatefulWidget {
  final AchievementWithProgress achievementWithProgress;

  const AchievementDetailSheet({
    super.key,
    required this.achievementWithProgress,
  });

  @override
  State<AchievementDetailSheet> createState() => _AchievementDetailSheetState();
}

class _AchievementDetailSheetState extends State<AchievementDetailSheet>
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

  @override
  Widget build(BuildContext context) {
    final achievement = widget.achievementWithProgress.achievement;
    final userAchievement = widget.achievementWithProgress.userAchievement;

    final isCompleted = userAchievement?.isCompleted ?? false;
    final isSecret = achievement.secret && !isCompleted;
    final visualState =
        userAchievement?.visualState ?? AchievementVisualState.locked;
    final tierColor = achievementTierColor(achievement.tier);
    final tierInk = achievementTierInkColor(achievement.tier);
    final tierChipBg = achievementTierChipBackground(
      achievement.tier,
      Theme.of(context).brightness,
    );
    final c = context.sac;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final wash = _tierSheetWash(
      tier: achievement.tier,
      unlocked: isCompleted,
      isSecret: isSecret,
      surface: c.surface,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: c.shadow,
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Stack(
              children: [
                // Tier wash — reads bronze/silver/gold/… without fighting content.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 320,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          wash,
                          wash.withValues(alpha: 0.45),
                          c.surface.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.border.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding:
                            EdgeInsets.fromLTRB(20, 16, 20, 28 + bottomInset),
                        child: FadeTransition(
                          opacity: _fade,
                          // Full-width column so Wrap/text always center in the sheet.
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Center(
                                  child: ScaleTransition(
                                    scale: _scale,
                                    child: _BadgeHero(
                                      achievement: achievement,
                                      visualState: visualState,
                                      isSecret: isSecret,
                                      tier: achievement.tier,
                                      tierColor: tierColor,
                                      progress:
                                          userAchievement?.progressPercentage ??
                                              0.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  isSecret ? '???' : achievement.name,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    height: 1.15,
                                    color: c.text,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _StatusChip(visualState: visualState),
                                      if (!isSecret) ...[
                                        _MetaChip(
                                          icon: HugeIcons.strokeRoundedAward01,
                                          label: achievement.tier.displayName,
                                          foreground: tierInk,
                                          background: tierChipBg,
                                        ),
                                        _MetaChip(
                                          icon: HugeIcons.strokeRoundedFlash,
                                          label: '${achievement.points} pts',
                                          foreground: AppColors.primary,
                                          background: AppColors.primary
                                              .withValues(alpha: 0.12),
                                        ),
                                        if (achievement.repeatable)
                                          _MetaChip(
                                            icon:
                                                HugeIcons.strokeRoundedRefresh,
                                            label:
                                                'achievements.views.detail_repeatable'
                                                    .tr(),
                                            foreground: c.textSecondary,
                                            background: c.surfaceVariant,
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSecret) ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      'achievements.views.detail_secret_hint'
                                          .tr(),
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.45,
                                        color: c.textSecondary,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ] else if (achievement
                                        .description?.isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      achievement.description!,
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.45,
                                        color: c.textSecondary,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                                if (isCompleted &&
                                    (userAchievement?.completedAt != null ||
                                        (achievement.repeatable &&
                                            (userAchievement?.timesCompleted ??
                                                    0) >
                                                0))) ...[
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: _CompletedCaption(
                                      completedAt: userAchievement?.completedAt,
                                      timesCompleted: achievement.repeatable
                                          ? userAchievement?.timesCompleted
                                          : null,
                                    ),
                                  ),
                                ],
                                if (!isSecret &&
                                    userAchievement != null &&
                                    !isCompleted) ...[
                                  const SizedBox(height: 20),
                                  _InsetCard(
                                    child: _ProgressSection(
                                      userAchievement: userAchievement,
                                      achievement: achievement,
                                    ),
                                  ),
                                ],
                                if (!isSecret) ...[
                                  const SizedBox(height: 12),
                                  _TypeSpecificContent(
                                    achievement: achievement,
                                    userAchievement: userAchievement,
                                  ),
                                ],
                                if (achievement.prerequisiteId != null) ...[
                                  const SizedBox(height: 4),
                                  _PrerequisiteCard(
                                    prerequisiteId: achievement.prerequisiteId!,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Soft sheet wash keyed to achievement tier.
Color _tierSheetWash({
  required AchievementTier tier,
  required bool unlocked,
  required bool isSecret,
  required Color surface,
}) {
  if (isSecret) {
    return Colors.black.withValues(alpha: 0.04);
  }

  final base = switch (tier) {
    AchievementTier.bronze => const Color(0xFFB87333),
    AchievementTier.silver => const Color(0xFF8E959D),
    AchievementTier.gold => const Color(0xFFE0B400),
    AchievementTier.platinum => const Color(0xFF9BA3AE),
    AchievementTier.diamond => const Color(0xFF5EC8E8),
    AchievementTier.unknown => Colors.grey,
  };

  final alpha = unlocked ? 0.22 : 0.10;
  return Color.alphaBlend(base.withValues(alpha: alpha), surface);
}

// ── Badge hero ─────────────────────────────────────────────────────────────────

class _BadgeHero extends StatelessWidget {
  final Achievement achievement;
  final AchievementVisualState visualState;
  final bool isSecret;
  final AchievementTier tier;
  final Color tierColor;
  final double progress;

  const _BadgeHero({
    required this.achievement,
    required this.visualState,
    required this.isSecret,
    required this.tier,
    required this.tierColor,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = visualState == AchievementVisualState.unlocked;
    final c = context.sac;
    final glowCore = unlocked
        ? tierColor.withValues(alpha: 0.42)
        : c.border.withValues(alpha: 0.28);
    final glowMid = unlocked
        ? tierColor.withValues(alpha: 0.18)
        : c.border.withValues(alpha: 0.12);

    return SizedBox(
      width: 255,
      height: 255,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft disc so tier reads even on locked badges.
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  glowCore,
                  glowMid,
                  glowMid.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          AchievementBadge(
            badgeImageUrl: achievement.badgeImageUrl,
            tier: tier,
            visualState: visualState,
            isSecret: isSecret,
            size: 203,
            progress: progress,
          ),
        ],
      ),
    );
  }
}

// ── Status / meta chips ────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final AchievementVisualState visualState;

  const _StatusChip({required this.visualState});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg, icon) = switch (visualState) {
      AchievementVisualState.unlocked => (
          'achievements.views.filter_unlocked'.tr(),
          AppColors.secondaryDark,
          AppColors.secondaryLight,
          HugeIcons.strokeRoundedCheckmarkCircle02,
        ),
      AchievementVisualState.inProgress => (
          'achievements.views.filter_in_progress'.tr(),
          AppColors.primaryDark,
          AppColors.primaryLight,
          HugeIcons.strokeRoundedLoading03,
        ),
      AchievementVisualState.locked => (
          'achievements.views.filter_locked'.tr(),
          context.sac.textSecondary,
          context.sac.surfaceVariant,
          HugeIcons.strokeRoundedLock,
        ),
    };

    return _MetaChip(
      icon: icon,
      label: label,
      foreground: fg,
      background: bg,
    );
  }
}

class _MetaChip extends StatelessWidget {
  final dynamic icon;
  final String label;
  final Color foreground;
  final Color background;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 13, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inset card shell ───────────────────────────────────────────────────────────

class _InsetCard extends StatelessWidget {
  final Widget child;

  const _InsetCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceVariant.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withValues(alpha: 0.55)),
      ),
      child: child,
    );
  }
}

// ── Completed caption (quiet metadata) ─────────────────────────────────────────

class _CompletedCaption extends StatelessWidget {
  final DateTime? completedAt;
  final int? timesCompleted;

  const _CompletedCaption({
    required this.completedAt,
    required this.timesCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final parts = <String>[];
    if (completedAt != null) {
      parts.add(
        '${'achievements.views.detail_completed_on'.tr()} ${_formatDate(completedAt!)}',
      );
    }
    if (timesCompleted != null && timesCompleted! > 0) {
      parts.add(
        '${'achievements.views.detail_times_completed'.tr()} · $timesCompleted',
      );
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join('  ·  '),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: c.textTertiary,
        height: 1.3,
        letterSpacing: 0.1,
      ),
      textAlign: TextAlign.center,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// ── Progress Section ───────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final UserAchievement userAchievement;
  final Achievement achievement;

  const _ProgressSection({
    required this.userAchievement,
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = achievementTierColor(achievement.tier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'achievements.views.detail_progress'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.sac.text,
              ),
            ),
            const Spacer(),
            Text(
              '${userAchievement.progressValue}/${userAchievement.progressTarget}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tierColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AchievementProgressBar(
          progress: userAchievement.progressPercentage,
          tier: achievement.tier,
          height: 7,
        ),
      ],
    );
  }
}

// ── Type-Specific Content ──────────────────────────────────────────────────────

class _TypeSpecificContent extends StatelessWidget {
  final Achievement achievement;
  final UserAchievement? userAchievement;

  const _TypeSpecificContent({
    required this.achievement,
    this.userAchievement,
  });

  @override
  Widget build(BuildContext context) {
    switch (achievement.type) {
      case AchievementType.collection:
        return _CollectionContent(
          achievement: achievement,
          userAchievement: userAchievement,
        );
      case AchievementType.streak:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _InsetCard(
            child: _StreakContent(
              achievement: achievement,
              userAchievement: userAchievement,
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _CollectionContent extends StatelessWidget {
  final Achievement achievement;
  final UserAchievement? userAchievement;

  const _CollectionContent({
    required this.achievement,
    this.userAchievement,
  });

  @override
  Widget build(BuildContext context) {
    final requiredItems =
        (achievement.criteria['items'] as List<dynamic>?)?.cast<String>() ?? [];
    final collectedItems =
        (userAchievement?.progressMetadata?['collected'] as List<dynamic>?)
                ?.cast<String>() ??
            [];

    if (requiredItems.isEmpty) return const SizedBox.shrink();

    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _InsetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'achievements.views.detail_collection'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            const SizedBox(height: 10),
            ...requiredItems.map((item) {
              final isCollected = collectedItems.contains(item);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: isCollected
                          ? HugeIcons.strokeRoundedCheckmarkCircle02
                          : HugeIcons.strokeRoundedCircle,
                      size: 18,
                      color: isCollected ? AppColors.secondary : c.textTertiary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isCollected ? FontWeight.w600 : FontWeight.w400,
                          color: isCollected ? c.text : c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StreakContent extends StatelessWidget {
  final Achievement achievement;
  final UserAchievement? userAchievement;

  const _StreakContent({
    required this.achievement,
    this.userAchievement,
  });

  @override
  Widget build(BuildContext context) {
    final currentStreak = userAchievement?.progressValue ?? 0;
    final requiredStreak = userAchievement?.progressTarget ??
        (achievement.criteria['streak'] as int? ?? 0);
    final tierColor = achievementTierColor(achievement.tier);
    final c = context.sac;

    return Column(
      children: [
        Text(
          'achievements.views.detail_streak'.tr(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$currentStreak',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
                height: 1,
                color: tierColor,
              ),
            ),
            if (requiredStreak > 0) ...[
              Text(
                ' / $requiredStreak',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'achievements.views.detail_streak_unit'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Prerequisite ───────────────────────────────────────────────────────────────

class _PrerequisiteCard extends StatelessWidget {
  final int prerequisiteId;

  const _PrerequisiteCard({required this.prerequisiteId});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return _InsetCard(
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedLink01,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'achievements.views.detail_prerequisite'.tr(
                namedArgs: {'id': '$prerequisiteId'},
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
