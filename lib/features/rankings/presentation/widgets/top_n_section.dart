import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/member_ranking.dart';

/// Sección que muestra el top-N anonimizado de la sección del miembro.
///
/// Solo se renderiza cuando [entries] no está vacío. Si el usuario no está
/// en el top-N visible, se agrega una fila inferior con su posición.
///
/// Los nombres ya vienen anonimizados desde el backend como "Miembro #N";
/// este widget los renderiza tal cual, sin transformación adicional.
class TopNSection extends StatelessWidget {
  final List<AnonymizedTopNEntry> entries;
  final int? userOwnRankPosition;
  final double? userOwnComposite;

  const TopNSection({
    super.key,
    required this.entries,
    this.userOwnRankPosition,
    this.userOwnComposite,
  });

  /// Formatea el puntaje compuesto para el badge lateral.
  String _formatScore(double value) {
    if (value == value.truncateToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  /// Determina si el usuario NO aparece ya en el top-N.
  bool get _userBelowTopN {
    if (userOwnRankPosition == null) return false;
    if (entries.isEmpty) return false;
    final lastTopN = entries
        .map((e) => e.rankPosition)
        .whereType<int>()
        .fold<int?>(null, (prev, r) => prev == null || r > prev ? r : prev);
    if (lastTopN == null) return false;
    return userOwnRankPosition! > lastTopN;
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu sección',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: c.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          Divider(color: c.borderLight, height: 1),
          const SizedBox(height: 4),

          // Filas del top-N.
          ...entries.map((entry) => _TopNRow(
                entry: entry,
                isCurrentUser: _isCurrentUserEntry(entry),
                formatScore: _formatScore,
              )),

          // Pie de página con posición del usuario fuera del top-N.
          if (_userBelowTopN) ...[
            Divider(color: c.borderLight, height: 1),
            const SizedBox(height: 6),
            Text(
              'Tu posición en la sección: #$userOwnRankPosition',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  /// Identifica si esta entrada corresponde al usuario actual comparando
  /// la posición. La lógica exacta depende del caller que pase ambos datos.
  bool _isCurrentUserEntry(AnonymizedTopNEntry entry) {
    if (userOwnRankPosition == null) return false;
    return entry.rankPosition == userOwnRankPosition;
  }
}

/// Fila individual del top-N.
class _TopNRow extends StatelessWidget {
  final AnonymizedTopNEntry entry;
  final bool isCurrentUser;
  final String Function(double) formatScore;

  const _TopNRow({
    required this.entry,
    required this.isCurrentUser,
    required this.formatScore,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.primarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Posición: 24dp fijo, bodySmall w600 textTertiary.
          SizedBox(
            width: 24,
            child: Text(
              entry.rankPosition != null ? '#${entry.rankPosition}' : '—',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.textTertiary,
                  ),
            ),
          ),
          const SizedBox(width: 8),

          // Nombre anonimizado.
          Expanded(
            child: Text(
              entry.memberName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.text,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Badge de puntaje compuesto.
          if (entry.compositeScorePct != null)
            _CompositeBadge(
              score: entry.compositeScorePct!,
              formatScore: formatScore,
            ),
        ],
      ),
    );
  }
}

/// Badge rectangular con el puntaje compuesto de cada miembro del top-N.
class _CompositeBadge extends StatelessWidget {
  final double score;
  final String Function(double) formatScore;

  const _CompositeBadge({required this.score, required this.formatScore});

  @override
  Widget build(BuildContext context) {
    // Color del badge: accent con 15% de opacidad; texto accent.
    const tierColor = AppColors.accent;

    return Container(
      width: 48,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        formatScore(score),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: tierColor,
              fontSize: 11,
            ),
      ),
    );
  }
}
