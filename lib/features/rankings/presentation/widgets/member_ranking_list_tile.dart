import 'package:flutter/material.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/award_tier.dart';

/// Fila de ranking de un miembro dentro de su sección.
///
/// Layout:
/// ```
/// [rank 32dp]  [nombre + sección opcional]     [score badge]
/// ```
///
/// Reglas visuales (según spec Task 26 / ui-ux-designer locked):
/// - Top 3: posición en `headlineSmall` 18px w700 `sac.text`.
/// - Resto:  posición en `titleSmall`   14px w500 `sac.textTertiary`.
/// - Score badge: 48×24dp, border-radius 6, bg = tier @ 12%, border = tier @ 40%.
/// - Sin score → bg = borderLight, text = textSecondary, guión "—".
///
/// NO usa [ListTile] nativo — el padding/height de ListTile no respeta el
/// mínimo de 56dp sin comprometer la especificación visual.
class MemberRankingListTile extends StatelessWidget {
  /// Posición 1-based del miembro en el ranking.
  final int rankPosition;

  /// Nombre real del miembro (vista de director — server-side RBAC).
  final String memberName;

  /// Nombre de la sección (opcional — solo se muestra si no es null).
  final String? sectionName;

  /// Puntaje compuesto 0-100 con un decimal. Null si aún no calculado.
  final double? compositeScore;

  /// Nombre de la categoría premiada (e.g. "Oro", "Plata"). Null si no asignada.
  final String? awardedCategoryName;

  /// Tier tipado de la categoría — determina el color del score badge.
  /// [AwardTier.unknown] cuando no hay categoría asignada (color neutro).
  final AwardTier awardedCategoryTier;

  /// Optional tap callback — wired by [SectionRankingScreen] to push the
  /// breakdown drill-down for this member.
  final VoidCallback? onTap;

  const MemberRankingListTile({
    super.key,
    required this.rankPosition,
    required this.memberName,
    this.sectionName,
    this.compositeScore,
    this.awardedCategoryName,
    this.awardedCategoryTier = AwardTier.unknown,
    this.onTap,
  });

  /// Resuelve el color del tier para el score badge desde el campo tipado.
  /// Usa los mismos valores hex que [achievementTierColor] para consistencia visual.
  Color _tierColor() {
    return awardedCategoryTier.color;
  }

  /// Formatea el puntaje con 1 decimal fijo para alineación de columna.
  // always 1 decimal — list column alignment vs single-value emphasis
  String _formatScore(double score) {
    return score.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final tierColor = _tierColor();
    final isTop3 = rankPosition <= 3;

    // Label de accesibilidad completo para VoiceOver/TalkBack.
    final semanticsLabel = [
      'Posición $rankPosition',
      memberName,
      if (sectionName != null) 'sección $sectionName',
      compositeScore != null
          ? 'puntaje ${_formatScore(compositeScore!)}'
          : 'puntaje no disponible',
      if (awardedCategoryName != null) 'categoría $awardedCategoryName',
    ].join(', ');

    final tile = Semantics(
      label: semanticsLabel,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Columna de posición ────────────────────────────────────
            SizedBox(
              width: 32,
              child: Text(
                '#$rankPosition',
                textAlign: TextAlign.center,
                style: isTop3
                    ? (Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ) ??
                        const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700))
                    : (Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: c.textTertiary,
                            ) ??
                        const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ),

            const SizedBox(width: 12),

            // ── Columna central: nombre + sección ─────────────────────
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memberName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: c.text,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sectionName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sectionName!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.textTertiary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Score badge ───────────────────────────────────────────
            _ScoreBadge(
              score: compositeScore,
              tierColor: tierColor,
              formatScore: _formatScore,
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return tile;

    return InkWell(
      onTap: onTap,
      child: tile,
    );
  }
}

// ── Score badge ───────────────────────────────────────────────────────────────

class _ScoreBadge extends StatelessWidget {
  final double? score;
  final Color tierColor;
  final String Function(double) formatScore;

  const _ScoreBadge({
    required this.score,
    required this.tierColor,
    required this.formatScore,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasScore = score != null;

    final bgColor =
        hasScore ? tierColor.withValues(alpha: 0.12) : c.borderLight;
    final borderColor =
        hasScore ? tierColor.withValues(alpha: 0.40) : c.borderLight;
    final textColor = hasScore ? tierColor : c.textSecondary;
    final label = hasScore ? formatScore(score!) : '—';

    return Container(
      width: 48,
      height: 24,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
