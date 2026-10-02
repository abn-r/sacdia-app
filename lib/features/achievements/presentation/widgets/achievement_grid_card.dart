import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';

import '../../domain/entities/user_achievement.dart';
import '../../domain/repositories/achievements_repository.dart';

const double _kArtSize = 72;
const double _kArtWidth = _kArtSize * 1.25;
const double _kCounterSlot = 24;
const double _kProgressSlot = 9;

/// Tarjeta de la grilla de logros. Misma estructura que la de maestrías:
/// imagen, contador, nombre y barra solo si hay avance.
class AchievementGridCard extends StatefulWidget {
  final AchievementWithProgress achievementWithProgress;
  final VoidCallback? onTap;
  final Duration animationDelay;

  const AchievementGridCard({
    super.key,
    required this.achievementWithProgress,
    this.onTap,
    this.animationDelay = Duration.zero,
  });

  @override
  State<AchievementGridCard> createState() => _AchievementGridCardState();
}

class _AchievementGridCardState extends State<AchievementGridCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _enterController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
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
    _scale = Tween<double>(begin: SacMotion.enterScale, end: 1).animate(
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

    if (reduceMotion) {
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
    final isUnlocked = visualState == AchievementVisualState.unlocked;

    final progressValue = userAchievement?.progressValue ?? 0;
    final progressPercentage = userAchievement?.progressPercentage ?? 0.0;
    final timesCompleted = userAchievement?.timesCompleted ?? 0;

    final showCounter =
        !isSecret && (isCompleted || (isInProgress && progressValue > 0));
    final counterLabel = isCompleted
        ? (achievement.repeatable && timesCompleted > 0
            ? timesCompleted.toString()
            : '1')
        : progressValue.toString();

    final reduce = _reduceMotion ?? SacMotion.reduceMotionOf(context);
    final c = context.sac;
    final accent = isUnlocked ? AppColors.secondary : AppColors.accent;

    final surfaceColor = isUnlocked || isInProgress
        ? c.surface
        : c.surfaceVariant.withValues(alpha: 0.55);
    final borderColor = isUnlocked
        ? AppColors.secondary.withValues(alpha: 0.45)
        : isInProgress
            ? c.border.withValues(alpha: 0.85)
            : c.border.withValues(alpha: 0.45);
    final nameColor = isCompleted ? c.text : c.textSecondary;
    final nameWeight = isCompleted ? FontWeight.w600 : FontWeight.w500;

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
          scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
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
              children: [
                SizedBox(
                  height: _kArtSize,
                  width: double.infinity,
                  child: Center(
                    child: _AchievementArt(
                      imageUrl: achievement.badgeImageUrl,
                      name: achievement.name,
                      secret: isSecret,
                      muted: !isUnlocked && !isSecret,
                      color: accent,
                    ),
                  ),
                ),
                SizedBox(
                  height: _kCounterSlot,
                  child: showCounter
                      ? Align(
                          alignment: Alignment.center,
                          child: _CounterPill(
                            label: counterLabel,
                            emphasized: isCompleted,
                            color: accent,
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      isSecret ? '???' : achievement.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: nameWeight,
                        color: nameColor,
                        height: 1.25,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(
                  height: _kProgressSlot,
                  child: isInProgress && !isSecret
                      ? Align(
                          alignment: Alignment.bottomCenter,
                          child: _ThinProgressBar(
                            progress: progressPercentage,
                            color: accent,
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
      child: ScaleTransition(
        scale: _scale,
        child: card,
      ),
    );
  }
}

class _AchievementArt extends StatelessWidget {
  const _AchievementArt({
    required this.imageUrl,
    required this.name,
    required this.secret,
    required this.muted,
    required this.color,
  });

  final String? imageUrl;
  final String name;
  final bool secret;
  final bool muted;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim() ?? '';
    final Widget art;
    if (secret) {
      art = SizedBox(
        width: _kArtWidth,
        height: _kArtSize,
        child: Center(
          child: Text(
            '?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: context.sac.textTertiary,
            ),
          ),
        ),
      );
    } else if (image.isEmpty) {
      art = _InitialsMark(initials: _initials(name), color: color);
    } else {
      art = ClipRect(
        child: SacNetworkImage(
          imageUrl: image,
          width: _kArtWidth,
          height: _kArtSize,
          fit: BoxFit.contain,
          memCacheWidth: (_kArtWidth * 3).round(),
          memCacheHeight: (_kArtSize * 3).round(),
          errorWidget: (_, __, ___) =>
              _InitialsMark(initials: _initials(name), color: color),
        ),
      );
    }

    if (!muted) return art;

    return ColorFiltered(
      colorFilter: _grayscaleFilter,
      child: Opacity(opacity: 0.58, child: art),
    );
  }
}

class _InitialsMark extends StatelessWidget {
  const _InitialsMark({required this.initials, required this.color});

  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kArtWidth,
      height: _kArtSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(60), width: 1.5),
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  const _CounterPill({
    required this.label,
    required this.emphasized,
    required this.color,
  });

  final String label;
  final bool emphasized;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: emphasized ? color.withValues(alpha: 0.16) : context.sac.border,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: emphasized ? color : context.sac.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class _ThinProgressBar extends StatelessWidget {
  const _ThinProgressBar({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

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
                      color: color,
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

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
}

const ColorFilter _grayscaleFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);
