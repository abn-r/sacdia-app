import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';

import '../../domain/entities/achievement.dart'
    show AchievementTier, kDefaultLockedAchievementBadgeUrl;
import '../../domain/entities/user_achievement.dart';

/// Color metálico del tier (glow, borde de badge, fill de progreso).
Color achievementTierColor(AchievementTier tier) => switch (tier) {
      AchievementTier.bronze => const Color(0xFFCD7F32),
      AchievementTier.silver => const Color(0xFFC0C0C0),
      AchievementTier.gold => const Color(0xFFFFD700),
      AchievementTier.platinum => const Color(0xFFE5E4E2),
      AchievementTier.diamond => const Color(0xFFB9F2FF),
      AchievementTier.unknown => Colors.grey,
    };

/// Tinta legible del tier para chips/labels (plata/oro/platino claros fallan en UI).
Color achievementTierInkColor(AchievementTier tier) => switch (tier) {
      AchievementTier.bronze => const Color(0xFF8B5314),
      AchievementTier.silver => const Color(0xFF4A5560),
      AchievementTier.gold => const Color(0xFF9A7200),
      AchievementTier.platinum => const Color(0xFF4E5664),
      AchievementTier.diamond => const Color(0xFF0E7FA3),
      AchievementTier.unknown => const Color(0xFF5A5A5A),
    };

/// Fondo de chip de tier con contraste suficiente sobre surface clara/oscura.
Color achievementTierChipBackground(
    AchievementTier tier, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return switch (tier) {
    AchievementTier.bronze => isDark
        ? const Color(0xFFCD7F32).withValues(alpha: 0.28)
        : const Color(0xFFF3D9B8),
    AchievementTier.silver => isDark
        ? const Color(0xFF9AA3AD).withValues(alpha: 0.32)
        : const Color(0xFFDDE2E8),
    AchievementTier.gold => isDark
        ? const Color(0xFFFFD700).withValues(alpha: 0.28)
        : const Color(0xFFF8E7A0),
    AchievementTier.platinum => isDark
        ? const Color(0xFFB8BEC8).withValues(alpha: 0.30)
        : const Color(0xFFE2E6EC),
    AchievementTier.diamond => isDark
        ? const Color(0xFFB9F2FF).withValues(alpha: 0.28)
        : const Color(0xFFC9EEF8),
    AchievementTier.unknown =>
      isDark ? Colors.grey.withValues(alpha: 0.28) : const Color(0xFFE5E5E5),
  };
}

/// Imagen del logro, sin aro alrededor.
///
/// - LOCKED e IN_PROGRESS: imagen en escala de grises.
///   Si es secreto y no está desbloqueado, muestra "???".
/// - UNLOCKED: imagen a color.
///   PLATINUM: shimmer. DIAMOND: shimmer y estrella.
class AchievementBadge extends StatefulWidget {
  final String? badgeImageUrl;
  final AchievementTier tier;
  final AchievementVisualState visualState;
  final bool isSecret;
  final double size;

  const AchievementBadge({
    super.key,
    required this.badgeImageUrl,
    required this.tier,
    required this.visualState,
    this.isSecret = false,
    this.size = 64,
  });

  @override
  State<AchievementBadge> createState() => _AchievementBadgeState();
}

class _AchievementBadgeState extends State<AchievementBadge>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final AnimationController _pulseController;
  late bool _reduceMotion;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = SacMotion.reduceMotionOf(context);
    _synchronizeAnimations();
  }

  @override
  void didUpdateWidget(AchievementBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visualState != widget.visualState ||
        oldWidget.tier != widget.tier) {
      _reduceMotion = SacMotion.reduceMotionOf(context);
      _synchronizeAnimations();
    }
  }

  void _synchronizeAnimations() {
    if (_reduceMotion) {
      _shimmerController
        ..stop()
        ..value = 0;
      _pulseController
        ..stop()
        ..value = 0;
      return;
    }

    final isUnlocked = widget.visualState == AchievementVisualState.unlocked;
    final shimmerEligible = isUnlocked &&
        (widget.tier == AchievementTier.platinum ||
            widget.tier == AchievementTier.diamond);
    final pulseEligible = isUnlocked && widget.tier == AchievementTier.diamond;

    if (shimmerEligible) {
      if (!_shimmerController.isAnimating) {
        _shimmerController.repeat(reverse: true);
      }
    } else {
      _shimmerController.stop();
    }

    if (pulseEligible) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUnlocked = widget.visualState == AchievementVisualState.unlocked;
    final isInProgress =
        widget.visualState == AchievementVisualState.inProgress;
    final isLocked = widget.visualState == AchievementVisualState.locked;
    final tierColor = achievementTierColor(widget.tier);
    final imageCacheSize = (widget.size * 3).round();
    final showSecret = widget.isSecret && !isUnlocked;

    Widget imageContent;

    final placeholderColor = context.sac.surfaceVariant;
    final placeholderTextColor = context.sac.textTertiary;

    if (showSecret) {
      // Secret achievement: show "???" text
      imageContent = Container(
        width: widget.size,
        height: widget.size,
        color: placeholderColor,
        child: Center(
          child: Text(
            '???',
            style: TextStyle(
              fontSize: widget.size * 0.28,
              fontWeight: FontWeight.w900,
              color: placeholderTextColor,
            ),
          ),
        ),
      );
    } else {
      // For locked achievements (or when admin hasn't uploaded a custom badge)
      // show the default locked placeholder from R2 instead of the per-achievement
      // image.  Unlocked achievements always use their own badgeImageUrl.
      final effectiveUrl = isUnlocked
          ? (widget.badgeImageUrl?.isNotEmpty == true
              ? widget.badgeImageUrl!
              : kDefaultLockedAchievementBadgeUrl)
          : kDefaultLockedAchievementBadgeUrl;

      imageContent = SacNetworkImage(
        imageUrl: effectiveUrl,
        width: widget.size,
        height: widget.size,
        memCacheWidth: imageCacheSize,
        memCacheHeight: imageCacheSize,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          width: widget.size,
          height: widget.size,
          color: placeholderColor,
          child: Center(
            child: SizedBox(
              width: widget.size * 0.4,
              height: widget.size * 0.4,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) =>
            _FallbackBadgeIcon(size: widget.size),
      );
    }

    // Escala de grises. Matriz, no BlendMode.saturation: ese modo se salía
    // del badge y pintaba de gris toda la grilla.
    if (isLocked || isInProgress) {
      imageContent = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: imageContent,
      );
    }

    // Apply shimmer for platinum and diamond unlocked
    if (isUnlocked &&
        (widget.tier == AchievementTier.platinum ||
            widget.tier == AchievementTier.diamond)) {
      imageContent = AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tierColor,
                  Colors.white,
                  tierColor,
                ],
                stops: [
                  (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                  _shimmerController.value.clamp(0.0, 1.0),
                  (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                ],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: child,
          );
        },
        child: imageContent,
      );
    }

    Widget badge = ClipRect(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: imageContent,
      ),
    );

    // Diamond: add sparkle star overlay on top
    if (isUnlocked && widget.tier == AchievementTier.diamond) {
      badge = Stack(
        alignment: Alignment.topRight,
        children: [
          badge,
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final scale = 1.0 + (_pulseController.value * 0.3);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size * 0.28,
                  height: widget.size * 0.28,
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedStar,
                    size: widget.size * 0.16,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    return badge;
  }
}

/// Fallback cuando no hay imagen del badge
class _FallbackBadgeIcon extends StatelessWidget {
  final double size;
  const _FallbackBadgeIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: context.sac.surfaceVariant,
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedAward01,
        size: size * 0.55,
        color: context.sac.textTertiary,
      ),
    );
  }
}
