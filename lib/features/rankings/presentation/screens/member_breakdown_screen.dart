import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../domain/entities/award_tier.dart';
import '../../domain/entities/member_breakdown.dart';
import '../providers/member_breakdown_provider.dart';
import '../widgets/ranking_empty_state.dart';
import '../widgets/ranking_skeleton.dart';

/// Pantalla de desglose de puntaje por componente de un miembro.
///
/// Muestra:
/// - Hero con nombre + puntaje compuesto + badge de categoría.
/// - 3 tarjetas de señal (clase, investidura, camporees) con detalle expandido.
/// - Fila de pesos aplicados con fuente.
/// - Estados skeleton, vacío y error estándar.
///
/// Recibe [enrollmentId] y [yearId] como parámetros de constructor.
/// Ambos se pasan como args al provider [memberBreakdownProvider].
class MemberBreakdownScreen extends ConsumerWidget {
  final int enrollmentId;
  final int yearId;

  const MemberBreakdownScreen({
    super.key,
    required this.enrollmentId,
    required this.yearId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (enrollmentId: enrollmentId, yearId: yearId);
    final breakdownAsync = ref.watch(memberBreakdownProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('rankings.breakdown.title')),
      ),
      body: breakdownAsync.when(
        data: (breakdown) => _BreakdownBody(breakdown: breakdown),
        loading: () => RankingSkeleton.myRanking(),
        error: (_, __) => RankingEmptyState(
          reason: RankingEmptyReason.networkError,
          onRetry: () => ref.invalidate(memberBreakdownProvider(params)),
        ),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────���────────────

class _BreakdownBody extends StatelessWidget {
  final MemberBreakdown breakdown;

  const _BreakdownBody({required this.breakdown});

  String _formatScore(double value) {
    if (value == value.truncateToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Hero ──────────────────────���─────────────────────��─────────────────
        SliverToBoxAdapter(
          child: _BreakdownHero(breakdown: breakdown),
        ),

        // ── Señal: Clase ─────────────────────────────────────────────��────────
        SliverToBoxAdapter(
          child: _SignalDetailCard(
            icon: HugeIcons.strokeRoundedBook01,
            title: tr('rankings.breakdown.class_section'),
            scorePct: breakdown.classScorePct,
            weightPct: breakdown.weights.classPct,
            formatScore: _formatScore,
            details: _classDetails(context, breakdown.classBreakdown),
          ),
        ),

        // ── Señal: Investidura ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SignalDetailCard(
            icon: HugeIcons.strokeRoundedMedal01,
            title: tr('rankings.breakdown.investiture_section'),
            scorePct: breakdown.investitureScorePct,
            weightPct: breakdown.weights.investiturePct,
            formatScore: _formatScore,
            details:
                _investitureDetails(context, breakdown.investitureBreakdown),
          ),
        ),

        // ── Señal: Camporees ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SignalDetailCard(
            icon: HugeIcons.strokeRoundedCampfire,
            title: tr('rankings.breakdown.camporee_section'),
            scorePct: breakdown.camporeeScorePct,
            weightPct: breakdown.weights.camporeePct,
            formatScore: _formatScore,
            details: _camporeeDetails(context, breakdown.camporeeBreakdown),
          ),
        ),

        // ── Pesos aplicados ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _WeightsSummary(weights: breakdown.weights),
        ),

        // ── Timestamp ─────────────────────────────────────────────────────────
        if (breakdown.compositeCalculatedAt != null)
          SliverToBoxAdapter(
            child: _CalculatedAtRow(
              calculatedAt: breakdown.compositeCalculatedAt!,
            ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  List<String> _classDetails(BuildContext context, ClassBreakdown cb) {
    final lines = <String>[
      tr('rankings.breakdown.class_completed_sections', namedArgs: {
        'completed': cb.completedSections.toString(),
        'required': cb.requiredSections.toString(),
      }),
    ];
    if (cb.folderStatus != null) {
      lines.add(
        tr('rankings.breakdown.class_folder_status',
            namedArgs: {'status': cb.folderStatus!}),
      );
    }
    return lines;
  }

  List<String> _investitureDetails(
      BuildContext context, InvestitureBreakdown ib) {
    if (ib.status == null) return [];
    return [
      tr('rankings.breakdown.investiture_status',
          namedArgs: {'status': ib.status!}),
    ];
  }

  List<String> _camporeeDetails(BuildContext context, CamporeeBreakdown cb) {
    final lines = <String>[
      cb.participated
          ? tr('rankings.breakdown.camporee_participated')
          : tr('rankings.breakdown.camporee_not_participated'),
    ];
    if (cb.totalCamporees != null) {
      lines.add(
        tr('rankings.breakdown.camporee_total',
            namedArgs: {'total': cb.totalCamporees.toString()}),
      );
    }
    return lines;
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _BreakdownHero extends StatelessWidget {
  final MemberBreakdown breakdown;

  const _BreakdownHero({required this.breakdown});

  Color _tierColor() {
    return breakdown.awardedCategory?.tier.color ?? AppColors.darkBorder;
  }

  String _formatScore(double score) {
    if (score == score.truncateToDouble()) return score.toStringAsFixed(0);
    return score.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor();
    final hasComposite = breakdown.compositeScorePct != null;

    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: tierColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              breakdown.memberName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (breakdown.awardedCategory != null)
                            _CategoryPill(
                              name: breakdown.awardedCategory!.name,
                              color: tierColor,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (hasComposite) ...[
                        Text(
                          _formatScore(breakdown.compositeScorePct!),
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 32,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('rankings.breakdown.composite_score'),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                        ),
                      ] else
                        Text(
                          tr('rankings.my_ranking.pending'),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String name;
  final Color color;

  const _CategoryPill({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        name.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

// ── Signal detail card ────────────────────────────────────────────────────────

class _SignalDetailCard extends StatelessWidget {
  final HugeIconData icon;
  final String title;
  final double? scorePct;
  final int weightPct;
  final String Function(double) formatScore;
  final List<String> details;

  const _SignalDetailCard({
    required this.icon,
    required this.title,
    this.scorePct,
    required this.weightPct,
    required this.formatScore,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasScore = scorePct != null;
    final scoreLabel = hasScore ? '${formatScore(scorePct!)}%' : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SacCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + title + score badge
            Row(
              children: [
                HugeIcon(
                  icon: icon,
                  size: 20,
                  color: hasScore ? AppColors.primary : c.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                  ),
                ),
                // Score + weight chip
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      scoreLabel,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: hasScore ? c.text : c.textTertiary,
                              ),
                    ),
                    Text(
                      tr('rankings.breakdown.weight_pct',
                          namedArgs: {'pct': weightPct.toString()}),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: c.textTertiary,
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
              ],
            ),

            // Detail lines
            if (details.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...details.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                        ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Weights summary ─────────────────────────────────��─────────────────────────

class _WeightsSummary extends StatelessWidget {
  final BreakdownWeights weights;

  const _WeightsSummary({required this.weights});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SacCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('rankings.breakdown.weights_title'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
            ),
            const SizedBox(height: 10),
            _WeightRow(
              label: tr('rankings.breakdown.class_section'),
              pct: weights.classPct,
            ),
            _WeightRow(
              label: tr('rankings.breakdown.investiture_section'),
              pct: weights.investiturePct,
            ),
            _WeightRow(
              label: tr('rankings.breakdown.camporee_section'),
              pct: weights.camporeePct,
            ),
            const SizedBox(height: 8),
            Text(
              tr('rankings.breakdown.weights_source',
                  namedArgs: {'source': weights.source}),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.textTertiary,
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightRow extends StatelessWidget {
  final String label;
  final int pct;

  const _WeightRow({required this.label, required this.pct});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                ),
          ),
          Text(
            '$pct%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Calculated at row ─────────────────────────────────────────────────────────

class _CalculatedAtRow extends StatelessWidget {
  final DateTime calculatedAt;

  const _CalculatedAtRow({required this.calculatedAt});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final formatted =
        DateFormat('dd/MM/yyyy HH:mm').format(calculatedAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        tr('rankings.breakdown.calculated_at', namedArgs: {'date': formatted}),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: c.textTertiary,
              fontSize: 10,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
