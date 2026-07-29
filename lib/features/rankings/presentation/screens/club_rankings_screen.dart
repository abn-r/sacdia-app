import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_back_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_network_image.dart';
import '../../../../features/auth/domain/entities/user_entity.dart';
import '../../../../features/auth/domain/utils/authorization_utils.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/members/presentation/providers/members_providers.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../domain/entities/annual_ranking_progress.dart';
import '../providers/annual_ranking_progress_provider.dart';
import '../utils/ranking_tier_medal_assets.dart';
import '../widgets/ranking_empty_state.dart';
import '../widgets/ranking_skeleton.dart';

class ClubRankingsScreen extends ConsumerWidget {
  const ClubRankingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authView = ref.watch(
      authNotifierProvider.select(
        (value) => (
          isLoading: value.isLoading,
          hasError: value.hasError,
          user: value.valueOrNull,
        ),
      ),
    );
    final ctxAsync = ref.watch(clubContextProvider);
    final yearAsync = ref.watch(currentEcclesiasticalYearProvider);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        title: Text(
          tr('rankings.annual_progress.title'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: c.text,
                letterSpacing: -0.2,
              ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: c.background.withValues(alpha: 0.92),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      body: Builder(
        builder: (context) {
          if (authView.isLoading) {
            return RankingSkeleton.annualProgress();
          }
          if (authView.hasError || !_canViewAnnualProgress(authView.user)) {
            return const RankingEmptyState(
              reason: RankingEmptyReason.unauthorized,
            );
          }

          return yearAsync.when(
            data: (year) {
              if (year == null) {
                return const RankingEmptyState(
                  reason: RankingEmptyReason.noData,
                );
              }

              return ctxAsync.when(
                data: (ctx) {
                  if (ctx == null) {
                    return const RankingEmptyState(
                      reason: RankingEmptyReason.unauthorized,
                    );
                  }

                  return _AnnualRankingProgressBody(
                    sectionId: ctx.sectionId,
                    yearId: year.ecclesiasticalYearId,
                    yearName: year.name,
                  );
                },
                loading: () => RankingSkeleton.annualProgress(),
                error: (_, __) => RankingEmptyState(
                  reason: RankingEmptyReason.networkError,
                  onRetry: () => ref.invalidate(clubContextProvider),
                ),
              );
            },
            loading: () => RankingSkeleton.annualProgress(),
            error: (_, __) => RankingEmptyState(
              reason: RankingEmptyReason.networkError,
              onRetry: () => ref.invalidate(currentEcclesiasticalYearProvider),
            ),
          );
        },
      ),
    );
  }
}

bool _canViewAnnualProgress(UserEntity? user) {
  return canViewClubRankings(user) || canViewSectionRankings(user);
}

class _AnnualRankingProgressBody extends ConsumerWidget {
  final int sectionId;
  final int yearId;
  final String yearName;

  const _AnnualRankingProgressBody({
    required this.sectionId,
    required this.yearId,
    required this.yearName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (sectionId: sectionId, yearId: yearId);
    final progressAsync = ref.watch(annualRankingProgressProvider(params));

    return progressAsync.when(
      data: (progress) => AnnualRankingProgressContent(
        progress: progress,
        yearName: yearName,
        onRefresh: () async =>
            ref.invalidate(annualRankingProgressProvider(params)),
      ),
      loading: () => RankingSkeleton.annualProgress(),
      error: (_, __) => RankingEmptyState(
        reason: RankingEmptyReason.networkError,
        onRetry: () => ref.invalidate(annualRankingProgressProvider(params)),
      ),
    );
  }
}

class AnnualRankingProgressContent extends StatelessWidget {
  final AnnualRankingProgress progress;
  final String yearName;
  final Future<void> Function() onRefresh;

  const AnnualRankingProgressContent({
    super.key,
    required this.progress,
    required this.yearName,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _ProgressHeroCard(progress: progress, yearName: yearName),
      const SizedBox(height: 12),
      if (progress.nextTier != null)
        _NextTierCard(
          tier: progress.nextTier!,
          currentPoints: progress.currentPoints,
        )
      else
        const _TopTierCard(),
      const SizedBox(height: 12),
      if (progress.axes.isNotEmpty)
        _AxesCard(axes: progress.axes)
      else
        _ComponentsCard(components: progress.components),
      const SizedBox(height: 12),
      _PendingItemsCard(items: progress.pendingItems),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: sections.length,
        itemBuilder: (context, index) => StaggeredListItem(
          index: index ~/ 2,
          staggerDelay: const Duration(milliseconds: 36),
          duration: const Duration(milliseconds: 200),
          slideOffset: 8,
          child: sections[index],
        ),
      ),
    );
  }
}

class _ProgressHeroCard extends StatelessWidget {
  final AnnualRankingProgress progress;
  final String yearName;

  const _ProgressHeroCard({required this.progress, required this.yearName});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final percent = (progress.progressPercentage / 100).clamp(0.0, 1.0);
    final progressColor = _progressColorFor(percent, c);

    return Semantics(
      label:
          '${tr('rankings.annual_progress.header_title')}, ${_formatPoints(progress.currentPoints)} ${tr('rankings.annual_progress.points_of_total', namedArgs: {
            'total': _formatPoints(progress.maxPoints)
          })}, ${tr('rankings.annual_progress.progress_percentage', namedArgs: {
            'percent': progress.progressPercentage.toStringAsFixed(0)
          })}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('rankings.annual_progress.header_title'),
              style: TextStyle(
                color: c.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              tr(
                'rankings.annual_progress.header_body',
                namedArgs: {
                  'club': progress.clubName,
                  'type': progress.clubType.name,
                  'year': yearName,
                },
              ),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AnimatedPoints(
                        value: progress.currentPoints,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          height: 0.95,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          'rankings.annual_progress.points_of_total',
                          namedArgs: {
                            'total': _formatPoints(progress.maxPoints),
                          },
                        ),
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CurrentTierBadge(tier: progress.currentTier),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _HeroRing(
                  progress: percent,
                  color: progressColor,
                  label:
                      '${progress.progressPercentage.clamp(0, 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroRing extends StatelessWidget {
  final double progress;
  final Color color;
  final String label;

  const _HeroRing({
    required this.progress,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final target = progress.clamp(0.0, 1.0);
    final reduce = SacMotion.reduceMotionOf(context);

    return SizedBox(
      width: 84,
      height: 84,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: target),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 800),
        curve: SacMotion.easeOut,
        builder: (context, value, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(84, 84),
                painter: _RingPainter(
                  progress: value,
                  color: color,
                  trackColor: c.surfaceVariant,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: c.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 7.0;
    final radius = size.width / 2 - stroke;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

/// Badge del rango actual — medalla + label. Sin rango usa look “locked” cálido.
class _CurrentTierBadge extends StatelessWidget {
  final RankingTier? tier;

  const _CurrentTierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final hasTier = tier?.name.trim().isNotEmpty == true;
    final palette = hasTier
        ? _tierPaletteFor(context, tier)
        : const _TierPalette(
            foreground: Color(0xFFB86A2D),
            background: Color(0xFFFFF1E0),
            gradient: [Color(0xFFFFE0B8), Color(0xFFFFF4E4)],
          );
    final label = hasTier
        ? tier!.name.trim()
        : tr('rankings.annual_progress.no_tier_yet');

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.gradient,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: palette.foreground.withValues(alpha: hasTier ? 0.28 : 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: palette.foreground.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TierMedal(tier: tier, size: 26, locked: !hasTier),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: palette.foreground,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextTierCard extends StatelessWidget {
  final RankingTier tier;
  final int currentPoints;

  const _NextTierCard({required this.tier, required this.currentPoints});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final pointsToReach = tier.pointsToReach;
    final palette = _tierPaletteFor(context, tier);
    final threshold = tier.fromPoints > 0 ? tier.fromPoints : tier.toPoints;
    final toward =
        threshold > 0 ? (currentPoints / threshold).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.gradient.first,
            Color.lerp(palette.gradient.last, c.surface, 0.15)!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.foreground.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: palette.foreground.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -22,
            // colorFilter evita Opacity+SVG (Impeller SetInheritedOpacity break).
            child: _TierMedal(tier: tier, size: 110, locked: false, fade: 0.18),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: palette.foreground.withValues(alpha: 0.18),
                    ),
                  ),
                  child: _TierMedal(tier: tier, size: 48, locked: false),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('rankings.annual_progress.next_tier').toUpperCase(),
                        style: TextStyle(
                          color: palette.foreground.withValues(alpha: 0.78),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tier.name,
                        style: TextStyle(
                          color: palette.foreground,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (pointsToReach != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          tr(
                            'rankings.annual_progress.points_to_reach',
                            namedArgs: {'points': _formatPoints(pointsToReach)},
                          ),
                          style: TextStyle(
                            color: c.text.withValues(alpha: 0.72),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _AnimatedProgressBar(
                        value: toward,
                        backgroundColor: palette.foreground.withValues(
                          alpha: 0.12,
                        ),
                        color: palette.foreground,
                        height: 5,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Medalla por tier.
///
/// Orden: URL remota (`imageUrl`) → SVG local por slug → icono award tintado.
class _TierMedal extends StatelessWidget {
  final RankingTier? tier;
  final double size;
  final bool locked;
  final double fade;

  const _TierMedal({
    required this.tier,
    required this.size,
    required this.locked,
    this.fade = 1,
  });

  @override
  Widget build(BuildContext context) {
    final fadeFilter = fade < 1
        ? ColorFilter.mode(
            Colors.white.withValues(alpha: fade),
            BlendMode.dstIn,
          )
        : null;

    final remoteUrl = tier?.imageUrl?.trim();
    if (!locked && remoteUrl != null && remoteUrl.isNotEmpty) {
      final image = SacNetworkImage(
        imageUrl: remoteUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        memCacheWidth: (size * 3).round(),
        memCacheHeight: (size * 3).round(),
        errorWidget: (_, __, ___) => _iconMedal(context),
      );
      return fadeFilter == null
          ? image
          : ColorFiltered(colorFilter: fadeFilter, child: image);
    }

    final asset = rankingTierLocalSvgAsset(tier?.slug ?? tier?.name);
    if (!locked && asset != null) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: fadeFilter,
        errorBuilder: (_, __, ___) => _iconMedal(context),
      );
    }

    return _iconMedal(context);
  }

  Widget _iconMedal(BuildContext context) {
    final palette = locked
        ? const _TierPalette(
            foreground: Color(0xFFB86A2D),
            background: Color(0xFFFFF1E0),
            gradient: [Color(0xFFFFE0B8), Color(0xFFFFF4E4)],
          )
        : _tierPaletteFor(context, tier);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.foreground.withValues(alpha: locked ? 0.18 : 0.95),
            palette.foreground.withValues(alpha: locked ? 0.08 : 0.72),
          ],
        ),
        border: locked
            ? Border.all(
                color: palette.foreground.withValues(alpha: 0.45),
                width: 1.5,
              )
            : null,
      ),
      child: HugeIcon(
        icon: locked
            ? HugeIcons.strokeRoundedLock
            : HugeIcons.strokeRoundedAward01,
        size: size * 0.48,
        color:
            locked ? palette.foreground : Colors.white.withValues(alpha: 0.95),
      ),
    );
  }
}

class _TopTierCard extends StatelessWidget {
  const _TopTierCard();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.lerp(c.surface, AppColors.secondaryLight, 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedAward01,
              size: 22,
              color: AppColors.secondaryDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('rankings.annual_progress.top_tier_reached'),
              style: const TextStyle(
                color: AppColors.secondaryDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentsCard extends StatelessWidget {
  final List<RankingComponentProgress> components;

  const _ComponentsCard({required this.components});

  @override
  Widget build(BuildContext context) {
    return SacCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: tr('rankings.annual_progress.components_title'),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < components.length; index++) ...[
            _ComponentRow(component: components[index]),
            if (index != components.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _AxesCard extends StatelessWidget {
  final List<RankingAxisProgress> axes;

  const _AxesCard({required this.axes});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: tr('rankings.annual_progress.components_title'),
          ),
          const SizedBox(height: 6),
          for (var index = 0; index < axes.length; index++) ...[
            _AxisSection(axis: axes[index]),
            if (index != axes.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Divider(height: 1, color: c.divider),
              ),
          ],
        ],
      ),
    );
  }
}

class _AxisSection extends StatelessWidget {
  final RankingAxisProgress axis;

  const _AxisSection({required this.axis});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final percent = (axis.progressPercentage / 100).clamp(0.0, 1.0);
    final accent = _axisAccentFor(axis.key);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  axis.label,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                tr(
                  'rankings.annual_progress.component_points',
                  namedArgs: {
                    'earned': _formatPoints(axis.earnedPoints),
                    'max': _formatPoints(axis.maxPoints),
                  },
                ),
                style: TextStyle(
                  color: _progressColorFor(percent, c, activeColor: accent),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _AnimatedProgressBar(
            value: percent,
            backgroundColor: c.surfaceVariant,
            color: _progressColorFor(percent, c, activeColor: accent),
            height: 5,
          ),
          if (axis.components.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var index = 0; index < axis.components.length; index++) ...[
              _ComponentRow(
                component: axis.components[index],
                accent: accent,
                indented: true,
              ),
              if (index != axis.components.length - 1)
                const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  final RankingComponentProgress component;
  final Color? accent;
  final bool indented;

  const _ComponentRow({
    required this.component,
    this.accent,
    this.indented = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final percent = (component.progressPercentage / 100).clamp(0.0, 1.0);
    final color = _progressColorFor(
      percent,
      c,
      activeColor: accent ?? AppColors.primary,
    );

    return Padding(
      padding: EdgeInsets.only(left: indented ? 2 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  component.label,
                  style: TextStyle(
                    color: c.text,
                    fontSize: indented ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                tr(
                  'rankings.annual_progress.component_points',
                  namedArgs: {
                    'earned': _formatPoints(component.earnedPoints),
                    'max': _formatPoints(component.maxPoints),
                  },
                ),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _AnimatedProgressBar(
            value: percent,
            backgroundColor: c.surfaceVariant,
            color: color,
            height: 3.5,
          ),
        ],
      ),
    );
  }
}

class _PendingItemsCard extends StatelessWidget {
  final List<RankingPendingItem> items;

  const _PendingItemsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasItems = items.isNotEmpty;

    return SacCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(title: tr('rankings.annual_progress.pending.title')),
          const SizedBox(height: 12),
          if (!hasItems)
            Text(
              tr('rankings.annual_progress.pending.empty'),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              _PendingItemTile(item: items[index]),
              if (index != items.length - 1) ...[
                const SizedBox(height: 8),
                Divider(height: 1, color: c.divider),
                const SizedBox(height: 8),
              ],
            ],
        ],
      ),
    );
  }
}

class _PendingItemTile extends StatelessWidget {
  final RankingPendingItem item;

  const _PendingItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  color: c.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(label: tr(item.statusLabelKey)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          [
            item.actionLabel,
            if (item.dueDate != null)
              tr(
                'rankings.annual_progress.pending.due_date',
                namedArgs: {'date': _formatDate(item.dueDate!)},
              ),
          ].join(' · '),
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;

  const _SectionHeading({required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Text(
      title,
      style: TextStyle(
        color: c.text,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.2,
      ),
    );
  }
}

/// Cuenta puntos con formato local (`7,200`) — interruptible vía Tween.
class _AnimatedPoints extends StatelessWidget {
  final int value;
  final TextStyle style;

  const _AnimatedPoints({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 700),
      curve: SacMotion.easeOut,
      builder: (context, animated, _) =>
          Text(_formatPoints(animated.round()), style: style),
    );
  }
}

class _AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final Color backgroundColor;
  final double height;

  const _AnimatedProgressBar({
    required this.value,
    required this.color,
    required this.backgroundColor,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    final safeValue = value.clamp(0.0, 1.0).toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: safeValue),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 650),
        curve: SacMotion.easeOut,
        builder: (context, animatedValue, _) {
          return LinearProgressIndicator(
            minHeight: height,
            value: animatedValue,
            backgroundColor: backgroundColor,
            color: color,
          );
        },
      ),
    );
  }
}

class _TierPalette {
  final Color foreground;
  final Color background;
  final List<Color> gradient;

  const _TierPalette({
    required this.foreground,
    required this.background,
    required this.gradient,
  });
}

_TierPalette _tierPaletteFor(BuildContext context, RankingTier? tier) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final key = (tier?.slug ?? tier?.name ?? '').toLowerCase();

  if (key.contains('bronze') || key.contains('bronce')) {
    return _TierPalette(
      foreground: const Color(0xFFB86A2D),
      background: isDark
          ? const Color(0xFFB86A2D).withValues(alpha: 0.18)
          : const Color(0xFFFFF1E0),
      gradient: isDark
          ? [
              const Color(0xFFB86A2D).withValues(alpha: 0.28),
              const Color(0xFFB86A2D).withValues(alpha: 0.12),
            ]
          : const [Color(0xFFFFE0B8), Color(0xFFFFF6EA)],
    );
  }
  if (key.contains('silver') || key.contains('plata')) {
    return _TierPalette(
      foreground: const Color(0xFF5B6B7C),
      background: isDark
          ? const Color(0xFF94A3B8).withValues(alpha: 0.18)
          : const Color(0xFFEEF2F6),
      gradient: isDark
          ? [
              const Color(0xFF94A3B8).withValues(alpha: 0.28),
              const Color(0xFF94A3B8).withValues(alpha: 0.12),
            ]
          : const [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
    );
  }
  if (key.contains('gold') || key.contains('oro')) {
    return _TierPalette(
      foreground: const Color(0xFF9A6B18),
      background: isDark
          ? const Color(0xFFD4A017).withValues(alpha: 0.18)
          : const Color(0xFFFFF4D6),
      gradient: isDark
          ? [
              const Color(0xFFD4A017).withValues(alpha: 0.28),
              const Color(0xFFD4A017).withValues(alpha: 0.12),
            ]
          : const [Color(0xFFFFE29A), Color(0xFFFFF8E7)],
    );
  }
  if (key.contains('diamond') || key.contains('diamante')) {
    return _TierPalette(
      foreground: const Color(0xFF0E7490),
      background: isDark
          ? const Color(0xFF22D3EE).withValues(alpha: 0.18)
          : const Color(0xFFE0F7FA),
      gradient: isDark
          ? [
              const Color(0xFF22D3EE).withValues(alpha: 0.28),
              const Color(0xFF22D3EE).withValues(alpha: 0.12),
            ]
          : const [Color(0xFFB2EBF2), Color(0xFFE0F7FA)],
    );
  }

  // Sin rango / desconocido — cálido (bronce locked), no mint apagado.
  return _TierPalette(
    foreground: const Color(0xFFB86A2D),
    background: isDark
        ? const Color(0xFFB86A2D).withValues(alpha: 0.18)
        : const Color(0xFFFFF1E0),
    gradient: isDark
        ? [
            const Color(0xFFB86A2D).withValues(alpha: 0.22),
            const Color(0xFFB86A2D).withValues(alpha: 0.10),
          ]
        : const [Color(0xFFFFE0B8), Color(0xFFFFF4E4)],
  );
}

Color _axisAccentFor(String key) {
  final normalized = key.toLowerCase();
  if (normalized.contains('oper')) return AppColors.secondary;
  if (normalized.contains('admin')) return AppColors.primary;
  return AppColors.accentDark;
}

Color _progressColorFor(
  double percent,
  SacColors colors, {
  Color activeColor = AppColors.primary,
}) {
  if (percent >= 1.0) return AppColors.secondary;
  if (percent <= 0.0) return colors.textTertiary;
  return activeColor;
}

String _formatPoints(int points) =>
    NumberFormat.decimalPattern().format(points);

String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
