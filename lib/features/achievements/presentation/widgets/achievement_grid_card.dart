import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/user_achievement.dart';
import '../../domain/repositories/achievements_repository.dart';
import 'achievement_badge.dart';

const double _kBadgeSize = 68;

/// Grid card v2 — badge-first, quieter chrome, press + enter motion.
///
/// Hierarchy:
/// - Unlocked: color badge, stronger name, optional counter
/// - In progress: progress ring + thin bar only
/// - Locked: muted surface, no empty "0" counter, no empty bar
/// - Secret + locked: "?" badge, "???" label
class AchievementGridCard extends StatefulWidget {
  final AchievementWithProgress achievementWithProgress;
  final VoidCallback? onTap;

  /// Stagger delay for entrance (capped by parent).
  final Duration animationDelay;

  /// When false, skip entrance and render at rest (filter/scroll reuse).
  final bool animateEntrance;

  const AchievementGridCard({
    super.key,
    required this.achievementWithProgress,
    this.onTap,
    this.animationDelay = Duration.zero,
    this.animateEntrance = true,
  });

  @override
  State<AchievementGridCard> createState() => _AchievementGridCardState();
}

class _AchievementGridCardState extends State<AchievementGridCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _enterController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _delayedStart;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: SacMotion.standard,
    );
    _fade = CurvedAnimation(parent: _enterController, curve: SacMotion.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _enterController, curve: SacMotion.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = SacMotion.reduceMotionOf(context);
    if (_reduceMotion == reduceMotion) return;

    final firstRead = _reduceMotion == null;
    _reduceMotion = reduceMotion;

    if (reduceMotion || !widget.animateEntrance) {
      _delayedStart?.cancel();
      _enterController.value = 1;
    } else if (firstRead) {
      _delayedStart = Timer(widget.animationDelay, () {
        if (mounted && _reduceMotion == false) _enterController.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayedStart?.cancel();
    _enterController.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final achievement = widget.achievementWithProgress.achievement;
    final userAchievement = widget.achievementWithProgress.userAchievement;

    final isCompleted = userAchievement?.isCompleted ?? false;
    final isSecret = achievement.secret && !isCompleted;
    final visualState =
        userAchievement?.visualState ?? AchievementVisualState.locked;
    final isInProgress = visualState == AchievementVisualState.inProgress;

    final progressValue = userAchievement?.progressValue ?? 0;
    final progressPercentage = userAchievement?.progressPercentage ?? 0.0;
    final timesCompleted = userAchievement?.timesCompleted ?? 0;
    final tierColor = achievementTierColor(achievement.tier);
    final tierInk = achievementTierInkColor(achievement.tier);

    final showCounter =
        !isSecret && (isCompleted || (isInProgress && progressValue > 0));
    final counterLabel = isCompleted
        ? (achievement.repeatable && timesCompleted > 0
            ? timesCompleted.toString()
            : '1')
        : progressValue.toString();

    final reduce = _reduceMotion ?? SacMotion.reduceMotionOf(context);
    final c = context.sac;

    final surfaceColor = switch (visualState) {
      AchievementVisualState.unlocked => c.surface,
      AchievementVisualState.inProgress => c.surface,
      AchievementVisualState.locked => c.surfaceVariant.withValues(alpha: 0.55),
    };

    final borderColor = switch (visualState) {
      // Ink (not metallic) so silver/gold borders stay visible on white cards.
      AchievementVisualState.unlocked => tierInk.withValues(alpha: 0.45),
      AchievementVisualState.inProgress => c.border.withValues(alpha: 0.85),
      AchievementVisualState.locked => c.border.withValues(alpha: 0.45),
    };

    final nameColor = isCompleted ? c.text : c.textSecondary;
    final nameWeight = isCompleted ? FontWeight.w600 : FontWeight.w500;

    // Fixed top stack keeps every badge on the same horizontal baseline.
    // Ring overflow (+8) and counter slot are always reserved.
    const badgeSize = _kBadgeSize;
    const badgeSlot = badgeSize + 8.0;
    const counterSlot = 24.0;
    const progressSlot = 9.0;

    Widget card = Semantics(
      button: true,
      label: isSecret ? '???' : achievement.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: (!reduce && _pressed) ? 0.97 : 1,
          duration: SacMotion.press,
          curve: SacMotion.easeOut,
          child: AnimatedContainer(
            duration: SacMotion.standard,
            curve: SacMotion.easeOut,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: badgeSlot,
                  width: badgeSlot,
                  child: Center(
                    child: isSecret
                        ? const _SecretBadge()
                        : AchievementBadge(
                            badgeImageUrl: achievement.badgeImageUrl,
                            tier: achievement.tier,
                            visualState: visualState,
                            isSecret: false,
                            size: badgeSize,
                            progress: progressPercentage,
                          ),
                  ),
                ),
                SizedBox(
                  height: counterSlot,
                  child: showCounter
                      ? Align(
                          alignment: Alignment.center,
                          child: _CounterPill(
                            label: counterLabel,
                            isCompleted: isCompleted,
                            tierColor: tierInk,
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        isSecret ? '???' : achievement.name,
                        style: TextStyle(
                          color: nameColor,
                          fontSize: 11.5,
                          fontWeight: nameWeight,
                          height: 1.25,
                          letterSpacing: 0.1,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: progressSlot,
                  child: (isInProgress && !isSecret)
                      ? Align(
                          alignment: Alignment.bottomCenter,
                          child: _ThinProgressBar(
                            progress: progressPercentage,
                            tierColor: tierColor,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (reduce) return card;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: card,
      ),
    );
  }
}

// ── Secret badge placeholder ────────────────────────────────────────────────────

class _SecretBadge extends StatelessWidget {
  const _SecretBadge();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: _kBadgeSize,
      height: _kBadgeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        border: Border.all(color: context.sac.border, width: 1.5),
      ),
      child: Center(
        child: Text(
          '?',
          style: TextStyle(
            fontSize: _kBadgeSize * 0.42,
            fontWeight: FontWeight.w800,
            color: context.sac.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ── Counter pill ────────────────────────────────────────────────────────────────

class _CounterPill extends StatelessWidget {
  final String label;
  final bool isCompleted;
  final Color tierColor;

  const _CounterPill({
    required this.label,
    required this.isCompleted,
    required this.tierColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isCompleted ? tierColor.withValues(alpha: 0.16) : context.sac.border;

    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isCompleted ? tierColor : context.sac.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

// ── Thin progress bar ───────────────────────────────────────────────────────────

class _ThinProgressBar extends StatelessWidget {
  final double progress; // 0.0 – 1.0
  final Color tierColor;

  const _ThinProgressBar({
    required this.progress,
    required this.tierColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final fillWidth = totalWidth * progress.clamp(0.0, 1.0);

          return ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(
                  height: 3,
                  width: totalWidth,
                  color: context.sac.border,
                ),
                if (fillWidth > 0)
                  AnimatedContainer(
                    duration: SacMotion.standard,
                    curve: SacMotion.easeOut,
                    height: 3,
                    width: fillWidth,
                    decoration: BoxDecoration(
                      color: tierColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
