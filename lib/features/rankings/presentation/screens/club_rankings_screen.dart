import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show listEquals;
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

/// Reveal compartido por número, track y barras: todo aterriza en el mismo
/// frame (una sola "voz" de movimiento en la pantalla).
const Duration _kReveal = Duration(milliseconds: 600);

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
          staggerDelay: SacMotion.stagger,
          duration: SacMotion.standard,
          slideOffset: 8,
          child: sections[index],
        ),
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

/// Una sola lectura del año: puntos → track con hitos de rango → escalera.
///
/// El track va de 0 al máximo anual; los hitos marcan el inicio del rango
/// actual y del siguiente, así el porcentaje y la distancia al próximo rango
/// viven en el mismo glifo (antes eran anillo + card separada).
class _ProgressHeroCard extends StatelessWidget {
  final AnnualRankingProgress progress;
  final String yearName;

  const _ProgressHeroCard({required this.progress, required this.yearName});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final current = progress.currentTier;
    final next = progress.nextTier;
    final hasCurrent = current?.name.trim().isNotEmpty == true;
    final percent =
        (progress.progressPercentage / 100).clamp(0.0, 1.0).toDouble();
    final percentLabel =
        '${progress.progressPercentage.clamp(0, 100).toStringAsFixed(0)}%';
    final fillColor = _progressColorFor(percent, c);
    final pointsToReach = next?.pointsToReach;

    final clubLine = tr(
      'rankings.annual_progress.header_body',
      namedArgs: {
        'club': progress.clubName,
        'type': progress.clubType.name,
        'year': yearName,
      },
    );
    final pointsOfTotal = tr(
      'rankings.annual_progress.points_of_total',
      namedArgs: {'total': _formatPoints(progress.maxPoints)},
    );
    final nextHint = pointsToReach == null
        ? null
        : tr(
            'rankings.annual_progress.points_to_reach',
            namedArgs: {'points': _formatPoints(pointsToReach)},
          );

    final semanticsLabel = [
      tr('rankings.annual_progress.header_title'),
      clubLine,
      '${_formatPoints(progress.currentPoints)} $pointsOfTotal',
      tr(
        'rankings.annual_progress.progress_percentage',
        namedArgs: {
          'percent': progress.progressPercentage.clamp(0, 100).toStringAsFixed(0)
        },
      ),
      hasCurrent
          ? current!.name.trim()
          : tr('rankings.annual_progress.no_tier_yet'),
      if (next != null)
        '${tr('rankings.annual_progress.next_tier')}: ${next.name}',
      if (nextHint != null) nextHint,
      if (next == null) tr('rankings.annual_progress.top_tier_reached'),
    ].join(', ');

    return Semantics(
      container: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: SacCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('rankings.annual_progress.header_title')
                            .toUpperCase(),
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clubLine,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      _AnimatedPoints(
                        value: progress.currentPoints,
                        style: TextStyle(
                          color: fillColor,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.6,
                          height: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pointsOfTotal,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _TierMedal(tier: current, size: 60, locked: !hasCurrent),
              ],
            ),
            const SizedBox(height: 18),
            _TierTrack(
              progress: percent,
              fillColor: fillColor,
              percentLabel: percentLabel,
              milestones: _milestonesFor(context, progress),
            ),
            const SizedBox(height: 14),
            _TierLadderRow(
              tier: current,
              locked: !hasCurrent,
              reached: true,
            ),
            const SizedBox(height: 10),
            if (next != null)
              _TierLadderRow(
                tier: next,
                locked: false,
                reached: false,
                hint: nextHint,
              )
            else
              const _TopTierRow(),
          ],
        ),
      ),
    );
  }
}

class _TrackMilestone {
  final double position;
  final Color color;

  const _TrackMilestone({required this.position, required this.color});

  @override
  bool operator ==(Object other) =>
      other is _TrackMilestone &&
      other.position == position &&
      other.color == color;

  @override
  int get hashCode => Object.hash(position, color);
}

List<_TrackMilestone> _milestonesFor(
  BuildContext context,
  AnnualRankingProgress progress,
) {
  final max = progress.maxPoints;
  if (max <= 0) return const [];

  final out = <_TrackMilestone>[];
  void add(RankingTier? tier) {
    if (tier == null) return;
    final from = tier.fromPoints;
    if (from <= 0 || from > max) return;
    out.add(
      _TrackMilestone(
        position: from / max,
        color: _tierColorFor(context, tier),
      ),
    );
  }

  add(progress.currentTier);
  add(progress.nextTier);
  return out;
}

/// Barra 0 → máximo anual con hitos de rango. El relleno se anima y cada hito
/// "se enciende" cuando el relleno lo cruza.
class _TierTrack extends StatelessWidget {
  final double progress;
  final Color fillColor;
  final String percentLabel;
  final List<_TrackMilestone> milestones;

  const _TierTrack({
    required this.progress,
    required this.fillColor,
    required this.percentLabel,
    required this.milestones,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 16,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: reduce ? Duration.zero : _kReveal,
              curve: SacMotion.easeOut,
              builder: (context, value, _) => CustomPaint(
                painter: _TierTrackPainter(
                  progress: value,
                  fillColor: fillColor,
                  trackColor: _trackColorOf(c),
                  surfaceColor: c.surface,
                  milestones: milestones,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          percentLabel,
          style: TextStyle(
            color: c.text,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: -0.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _TierTrackPainter extends CustomPainter {
  final double progress;
  final Color fillColor;
  final Color trackColor;
  final Color surfaceColor;
  final List<_TrackMilestone> milestones;

  static const double _barHeight = 8;
  static const double _dotRadius = 4.5;
  static const double _dotRing = 2;

  const _TierTrackPainter({
    required this.progress,
    required this.fillColor,
    required this.trackColor,
    required this.surfaceColor,
    required this.milestones,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final radius = Radius.circular(_barHeight / 2);
    final barTop = cy - _barHeight / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, barTop, size.width, _barHeight),
        radius,
      ),
      Paint()..color = trackColor,
    );

    if (progress > 0) {
      final fillWidth = math.max(_barHeight, size.width * progress);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, barTop, fillWidth, _barHeight),
          radius,
        ),
        Paint()..color = fillColor,
      );
    }

    final outer = _dotRadius + _dotRing;
    for (final m in milestones) {
      final x = (size.width * m.position).clamp(outer, size.width - outer);
      final center = Offset(x, cy);
      final reached = progress + 0.0005 >= m.position;

      // Anillo en color de superficie: el hito "recorta" la barra.
      canvas.drawCircle(center, outer, Paint()..color = surfaceColor);
      if (reached) {
        canvas.drawCircle(center, _dotRadius, Paint()..color = m.color);
      } else {
        canvas.drawCircle(
          center,
          _dotRadius - 1,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = m.color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TierTrackPainter old) =>
      old.progress != progress ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor ||
      old.surfaceColor != surfaceColor ||
      !listEquals(old.milestones, milestones);
}

/// Fila de la escalera: rango actual (medalla plena + check) o siguiente
/// (medalla atenuada + puntos faltantes).
class _TierLadderRow extends StatelessWidget {
  final RankingTier? tier;
  final bool locked;
  final bool reached;
  final String? hint;

  const _TierLadderRow({
    required this.tier,
    required this.locked,
    required this.reached,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final name = locked
        ? tr('rankings.annual_progress.no_tier_yet')
        : tier!.name.trim();

    return Row(
      crossAxisAlignment:
          hint == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        _TierMedal(
          tier: tier,
          size: 26,
          locked: locked,
          fade: reached || locked ? 1 : 0.55,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: locked ? c.textSecondary : c.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.2,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (reached && !locked) ...[
          const SizedBox(width: 8),
          HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            size: 18,
            color: c.success,
          ),
        ],
      ],
    );
  }
}

class _TopTierRow extends StatelessWidget {
  const _TopTierRow();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.success.withValues(alpha: 0.14),
          ),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedMedal05,
            size: 14,
            color: c.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              tr('rankings.annual_progress.top_tier_reached'),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
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
    // colorFilter evita Opacity+SVG (Impeller SetInheritedOpacity break).
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
    final color = _tierColorFor(context, locked ? null : tier);

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
            color.withValues(alpha: locked ? 0.18 : 0.95),
            color.withValues(alpha: locked ? 0.08 : 0.72),
          ],
        ),
        border: locked
            ? Border.all(color: color.withValues(alpha: 0.45), width: 1.5)
            : null,
      ),
      child: HugeIcon(
        icon: locked
            ? HugeIcons.strokeRoundedLock
            : HugeIcons.strokeRoundedMedal05,
        size: size * 0.48,
        color: locked ? color : Colors.white.withValues(alpha: 0.95),
      ),
    );
  }
}

// ─── Desglose ────────────────────────────────────────────────────────────────

class _ComponentsCard extends StatelessWidget {
  final List<RankingComponentProgress> components;

  const _ComponentsCard({required this.components});

  @override
  Widget build(BuildContext context) {
    return SacCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: tr('rankings.annual_progress.components_title'),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < components.length; index++) ...[
            _ComponentRow(
              component: components[index],
              accent: AppColors.primary,
            ),
            if (index != components.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Un eje = una barra. Los componentes se leen como filas compactas con una
/// micro-barra y el ratio tipográfico (ganado fuerte, máximo atenuado).
class _AxesCard extends StatelessWidget {
  final List<RankingAxisProgress> axes;

  const _AxesCard({required this.axes});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: tr('rankings.annual_progress.components_title'),
          ),
          const SizedBox(height: 4),
          for (var index = 0; index < axes.length; index++) ...[
            _AxisSection(axis: axes[index]),
            if (index != axes.length - 1)
              Divider(height: 1, color: c.divider),
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
    final percent = (axis.progressPercentage / 100).clamp(0.0, 1.0).toDouble();
    final accent = _axisAccentFor(axis.key);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Row(
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
                const SizedBox(width: 12),
                _RatioText(
                  earned: axis.earnedPoints,
                  max: axis.maxPoints,
                  fontSize: 12.5,
                  strong: _valueColorFor(percent, c),
                  muted: c.textTertiary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: _AnimatedBar(
              value: percent,
              color: _progressColorFor(percent, c, activeColor: accent),
              trackColor: _trackColorOf(c),
              height: 6,
            ),
          ),
          if (axis.components.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var index = 0; index < axis.components.length; index++) ...[
              _ComponentRow(
                component: axis.components[index],
                accent: accent,
              ),
              if (index != axis.components.length - 1)
                const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  final RankingComponentProgress component;
  final Color accent;

  const _ComponentRow({required this.component, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final percent =
        (component.progressPercentage / 100).clamp(0.0, 1.0).toDouble();

    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Text(
              component.label,
              style: TextStyle(
                color: c.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          ExcludeSemantics(
            child: SizedBox(
              width: 40,
              child: _AnimatedBar(
                value: percent,
                color: _progressColorFor(percent, c, activeColor: accent),
                trackColor: _trackColorOf(c),
                height: 4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: _RatioText(
                earned: component.earnedPoints,
                max: component.maxPoints,
                fontSize: 12,
                strong: _valueColorFor(percent, c),
                muted: c.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `{earned} / {max} pts` con el ganado en fuerte y el resto atenuado.
/// Parte la cadena i18n en el sub-string del ganado; si no lo encuentra,
/// cae a una sola tinta.
class _RatioText extends StatelessWidget {
  final int earned;
  final int max;
  final double fontSize;
  final Color strong;
  final Color muted;

  const _RatioText({
    required this.earned,
    required this.max,
    required this.fontSize,
    required this.strong,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final earnedText = _formatPoints(earned);
    final full = tr(
      'rankings.annual_progress.component_points',
      namedArgs: {'earned': earnedText, 'max': _formatPoints(max)},
    );
    final base = TextStyle(
      color: muted,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final index = full.indexOf(earnedText);
    if (index < 0) {
      return Text(full, style: base.copyWith(color: strong), maxLines: 1);
    }

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          if (index > 0) TextSpan(text: full.substring(0, index)),
          TextSpan(
            text: earnedText,
            style: TextStyle(color: strong, fontWeight: FontWeight.w800),
          ),
          TextSpan(text: full.substring(index + earnedText.length)),
        ],
      ),
      maxLines: 1,
      softWrap: false,
    );
  }
}

// ─── Pendientes ──────────────────────────────────────────────────────────────

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
          Row(
            children: [
              Expanded(
                child: _SectionHeading(
                  title: tr('rankings.annual_progress.pending.title'),
                ),
              ),
              if (hasItems) ...[
                const SizedBox(width: 10),
                _CountPill(count: items.length),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (!hasItems)
            const _PendingEmptyRow()
          else
            for (var index = 0; index < items.length; index++) ...[
              _PendingItemTile(item: items[index]),
              if (index != items.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: c.divider),
                ),
            ],
        ],
      ),
    );
  }
}

class _PendingEmptyRow extends StatelessWidget {
  const _PendingEmptyRow();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.success.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            size: 18,
            color: c.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            tr('rankings.annual_progress.pending.empty'),
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingItemTile extends StatelessWidget {
  final RankingPendingItem item;

  const _PendingItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final tone = _pendingToneFor(context, item);
    final due = item.dueDate;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: HugeIcon(icon: tone.icon, size: 18, color: tone.foreground),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título a todo el ancho: el chip vive en la línea de meta para
              // no forzar saltos de línea en títulos cortos.
              Text(
                item.title,
                style: TextStyle(
                  color: c.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              // Wrap: si la meta no cabe junto al chip, baja entera a la
              // siguiente línea en vez de partirse a mitad de frase.
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusChip(label: tr(item.statusLabelKey), tone: tone),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: item.actionLabel),
                        if (due != null) ...[
                          const TextSpan(text: ' · '),
                          TextSpan(
                            text: tr(
                              'rankings.annual_progress.pending.due_date',
                              namedArgs: {'date': _formatDate(due)},
                            ),
                            style: tone.overdue
                                ? TextStyle(
                                    color: tone.foreground,
                                    fontWeight: FontWeight.w700,
                                  )
                                : null,
                          ),
                        ],
                      ],
                    ),
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final _PendingTone tone;

  const _StatusChip({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone.foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;

  const _CountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _trackColorOf(c),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          height: 1.2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _PendingTone {
  final Color foreground;
  final Color background;
  final List<List<dynamic>> icon;
  final bool overdue;

  const _PendingTone({
    required this.foreground,
    required this.background,
    required this.icon,
    this.overdue = false,
  });
}

/// Tono por estado: entrega pendiente (ámbar), en validación/revisión (azul),
/// entrega vencida (rojo). Solo la entrega puede "vencer": si ya está en
/// validación, la fecha pasada no es culpa del club.
_PendingTone _pendingToneFor(BuildContext context, RankingPendingItem item) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final kind = item.statusLabelKey.split('.').last;
  final isDelivery = kind == 'pending_delivery';
  final due = item.dueDate;
  final today = DateTime.now();
  final overdue = isDelivery &&
      due != null &&
      due.isBefore(DateTime(today.year, today.month, today.day));

  _PendingTone tone({
    required Color color,
    required Color dark,
    required Color bg,
    required List<List<dynamic>> icon,
    bool overdue = false,
  }) =>
      _PendingTone(
        foreground: isDark ? color : dark,
        background: isDark ? color.withValues(alpha: 0.18) : bg,
        icon: icon,
        overdue: overdue,
      );

  if (overdue) {
    return tone(
      color: AppColors.rejectedColor,
      dark: AppColors.rejectedDark,
      bg: AppColors.rejectedBg,
      icon: HugeIcons.strokeRoundedAlert02,
      overdue: true,
    );
  }
  if (isDelivery) {
    return tone(
      color: AppColors.observedColor,
      dark: AppColors.observedDark,
      bg: AppColors.observedBg,
      icon: HugeIcons.strokeRoundedUpload01,
    );
  }
  if (kind == 'pending_validation' ||
      kind == 'pending_union_validation' ||
      kind == 'pending_review') {
    return tone(
      color: AppColors.sentColor,
      dark: AppColors.sentDark,
      bg: AppColors.sentBg,
      icon: HugeIcons.strokeRoundedClock01,
    );
  }
  return tone(
    color: AppColors.pendingColor,
    dark: AppColors.pendingDark,
    bg: AppColors.pendingBg,
    icon: HugeIcons.strokeRoundedClock01,
  );
}

// ─── Piezas compartidas ──────────────────────────────────────────────────────

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
      duration: reduce ? Duration.zero : _kReveal,
      curve: SacMotion.easeOut,
      builder: (context, animated, _) =>
          Text(_formatPoints(animated.round()), style: style),
    );
  }
}

/// Barra plana (sin semántica Material) — relleno interruptible vía Tween.
class _AnimatedBar extends StatelessWidget {
  final double value;
  final Color color;
  final Color trackColor;
  final double height;

  const _AnimatedBar({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    final safeValue = value.clamp(0.0, 1.0).toDouble();
    final radius = BorderRadius.circular(height);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        color: trackColor,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: safeValue),
          duration: reduce ? Duration.zero : _kReveal,
          curve: SacMotion.easeOut,
          builder: (context, animated, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: animated,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Color de tier con variante dark legible sobre `#1A1A1A`.
Color _tierColorFor(BuildContext context, RankingTier? tier) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final key = (tier?.slug ?? tier?.name ?? '').toLowerCase();

  if (key.contains('silver') || key.contains('plata')) {
    return isDark ? const Color(0xFFA3B1C2) : const Color(0xFF5B6B7C);
  }
  if (key.contains('gold') || key.contains('oro')) {
    return isDark ? const Color(0xFFE0B341) : const Color(0xFF9A6B18);
  }
  if (key.contains('diamond') || key.contains('diamante')) {
    return isDark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490);
  }
  // Bronce, sin rango o desconocido — cálido.
  return isDark ? const Color(0xFFD28C52) : const Color(0xFFB86A2D);
}

Color _axisAccentFor(String key) {
  final normalized = key.toLowerCase();
  if (normalized.contains('oper')) return AppColors.secondary;
  if (normalized.contains('admin')) return AppColors.info;
  return AppColors.accentDark;
}

/// Pista neutra visible en ambos modos (7% de tinta sobre la superficie).
Color _trackColorOf(SacColors colors) =>
    Color.alphaBlend(colors.text.withValues(alpha: 0.07), colors.surface);

Color _progressColorFor(
  double percent,
  SacColors colors, {
  Color activeColor = AppColors.primary,
}) {
  if (percent >= 1.0) return AppColors.secondary;
  if (percent <= 0.0) return colors.textTertiary;
  return activeColor;
}

/// Tinta del valor numérico: completo → éxito, cero → terciario, resto → texto.
Color _valueColorFor(double percent, SacColors colors) {
  if (percent >= 1.0) return colors.success;
  if (percent <= 0.0) return colors.textTertiary;
  return colors.text;
}

String _formatPoints(int points) =>
    NumberFormat.decimalPattern().format(points);

String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
