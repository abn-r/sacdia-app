import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/award_tier.dart';

/// Hero card con fondo oscuro (#1A1A1A) que muestra el puntaje compuesto del
/// miembro como ancla visual principal.
///
/// Reglas de renderizado:
/// - composite + rank presentes → layout completo.
/// - composite presente + rank null → compuesto + sub-label, sin línea de rank.
/// - ambos null → "Ranking pendiente" sin filas de datos.
class RankingHeroCard extends StatelessWidget {
  final double? compositeScore;
  final int? rankPosition;
  final int? totalInSection;
  final String? awardedCategoryName;
  final AwardTier awardedCategoryTier;
  final String? sectionName;
  final String ecclesiasticalYearLabel;

  const RankingHeroCard({
    super.key,
    this.compositeScore,
    this.rankPosition,
    this.totalInSection,
    this.awardedCategoryName,
    this.awardedCategoryTier = AwardTier.unknown,
    this.sectionName,
    required this.ecclesiasticalYearLabel,
  });

  /// Resuelve el color del tier desde el campo tipado [awardedCategoryTier].
  /// Usa los mismos valores hex que [achievementTierColor] para consistencia visual.
  Color _tierColor() {
    if (awardedCategoryTier == AwardTier.unknown) {
      return AppColors.darkBorder;
    }
    return awardedCategoryTier.color;
  }

  /// Formatea el puntaje: 1 decimal cuando la parte fraccionaria != 0.
  String _formatScore(double score) {
    if (score == score.truncateToDouble()) {
      return score.toStringAsFixed(0);
    }
    return score.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor();
    final hasComposite = compositeScore != null;
    final hasRank = rankPosition != null;

    final rankLine = hasRank
        ? (totalInSection != null
            ? '#$rankPosition de $totalInSection'
            : '#$rankPosition')
        : null;

    final semanticLabel = [
      hasComposite
          ? 'Tu puntaje compuesto es ${_formatScore(compositeScore!)}'
          : tr('rankings.my_ranking.pending'),
      if (rankLine != null) 'posición $rankLine',
      if (awardedCategoryName != null) 'categoría $awardedCategoryName',
    ].join(', ');

    return Semantics(
      label: semanticLabel,
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
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
                // Barra de acento lateral de 4px con color del tier.
                Container(width: 4, color: tierColor),

                // Contenido principal.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Fila superior: pill de categoría + año eclesiástico.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (awardedCategoryName != null)
                              _CategoryPill(
                                name: awardedCategoryName!,
                                color: tierColor,
                              )
                            else
                              const SizedBox.shrink(),
                            Text(
                              ecclesiasticalYearLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Puntaje compuesto o mensaje pendiente.
                        if (hasComposite) ...[
                          Text(
                            _formatScore(compositeScore!),
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
                            tr('rankings.my_ranking.composite_score'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                          ),
                        ] else ...[
                          Text(
                            tr('rankings.my_ranking.pending'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                          ),
                        ],

                        // Línea de posición (solo si rankPosition != null).
                        if (hasRank) ...[
                          const SizedBox(height: 8),
                          Text(
                            '$rankLine'
                            '${sectionName != null ? ' · ${tr('rankings.my_ranking.section_label', namedArgs: {
                                    'name': sectionName!
                                  })}' : ''}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 14,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill pequeña con el nombre de la categoría premiada.
class _CategoryPill extends StatelessWidget {
  final String name;
  final Color color;

  const _CategoryPill({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 80),
      child: Container(
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
      ),
    );
  }
}
