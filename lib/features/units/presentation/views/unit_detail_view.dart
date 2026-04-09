import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';

import '../../../../features/members/presentation/providers/members_providers.dart';
import '../../domain/entities/scoring_category.dart';
import '../../domain/entities/unit.dart';
import '../../domain/entities/unit_member.dart';
import '../providers/units_providers.dart';

/// Vista de detalle de una unidad: lista de miembros con control de puntos.
///
/// Muestra:
/// - Header con info de la unidad
/// - Banner de "ya registrado hoy" si [isSavedToday]
/// - Lista de miembros con puntaje dinámico por categoría
/// - Footer sticky con botón de guardar
///
/// Permisos:
/// - Club directors, consejeros y capitán: pueden registrar/editar puntos.
/// - Resto: vista de solo lectura.
class UnitDetailView extends ConsumerWidget {
  final Unit unit;

  const UnitDetailView({super.key, required this.unit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(unitsNotifierProvider);
    final notifier = ref.read(unitsNotifierProvider.notifier);
    final c = context.sac;

    // Determinar si el usuario actual puede registrar puntos
    final clubContextAsync = ref.watch(clubContextProvider);
    final canRegisterPoints = clubContextAsync.maybeWhen(
      data: (ctx) {
        if (ctx == null) return false;
        final role = ctx.roleName?.toLowerCase() ?? '';
        // Club directors
        if (['director', 'sub_director', 'secretario',
            'secretario_tesorero'].contains(role)) {
          return true;
        }
        // Consejeros o capitán de esta unidad
        final authState = ref.read(authNotifierProvider).value;
        final userId = authState?.userId ?? '';
        if (userId.isEmpty) return false;
        return unit.advisorId == userId ||
            unit.substituteAdvisorId == userId ||
            unit.captainId == userId;
      },
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(unit.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Contenido scrollable ──────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              children: [
                // Header — info de la unidad
                _UnitHeader(unit: unit),
                const SizedBox(height: 12),

                // Banner "ya guardado hoy"
                if (state.isSavedToday) ...[
                  _SavedTodayBanner(),
                  const SizedBox(height: 12),
                ],

                // Título sección miembros
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    canRegisterPoints ? 'Puntos del dia' : 'Puntajes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: c.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),

                // Lista de miembros con puntajes por categoría
                ...state.members.map((member) {
                  final memberScores =
                      state.pendingScores[member.id] ?? {};
                  final total = state.totalPendingForMember(member.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MemberCategoryScoreCard(
                      member: member,
                      categories: state.categories,
                      scores: memberScores,
                      total: total,
                      totalMax: state.totalMaxPoints,
                      isDisabled: state.isSavedToday || !canRegisterPoints,
                      isReadOnly: !canRegisterPoints,
                      onAdjust: (categoryId, delta) {
                        notifier.adjustCategoryPoints(
                            member.id, categoryId, delta);
                      },
                      onSetValue: (categoryId, value) {
                        notifier.setCategoryPoints(
                            member.id, categoryId, value);
                      },
                    ),
                  );
                }),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Footer sticky ─────────────────────────────────────────
          if (canRegisterPoints)
            _SaveFooter(
              isSavedToday: state.isSavedToday,
              onSave: () => _handleSave(context, notifier),
              onReset: () => notifier.resetSession(),
            ),
        ],
      ),
    );
  }

  void _handleSave(BuildContext context, UnitsNotifier notifier) {
    notifier.saveSession().then((saved) {
      if (!context.mounted) return;
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Todos los miembros deben tener puntaje o ninguno.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Puntos del dia guardados correctamente'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _UnitHeader extends StatelessWidget {
  final Unit unit;

  const _UnitHeader({required this.unit});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacCard(
      accentColor: AppColors.primary,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedUserGroup,
              size: 24,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.type,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${unit.memberCount} miembros',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
                if (unit.leaderName != null)
                  Text(
                    'Lider: ${unit.leaderName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.textTertiary,
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

class _SavedTodayBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            size: 20,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ya registraste los puntos de hoy',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryDark,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card de un miembro con puntaje dinámico por categoría.
///
/// Cuando hay categorías configuradas, muestra una fila por categoría
/// con stepper +/- y el indicador "actual / max".
///
/// Cuando no hay categorías (cargando o error), muestra un fallback simple.
class _MemberCategoryScoreCard extends StatelessWidget {
  final UnitMember member;
  final List<ScoringCategory> categories;

  /// Mapa de categoryId → puntos actuales del miembro.
  final Map<int, int> scores;

  /// Suma de todos los puntajes de este miembro.
  final int total;

  /// Máximo total posible (suma de maxPoints de todas las categorías).
  final int totalMax;

  final bool isDisabled;
  final bool isReadOnly;
  final void Function(int categoryId, int delta) onAdjust;
  final void Function(int categoryId, int value) onSetValue;

  const _MemberCategoryScoreCard({
    required this.member,
    required this.categories,
    required this.scores,
    required this.total,
    required this.totalMax,
    required this.isDisabled,
    required this.isReadOnly,
    required this.onAdjust,
    required this.onSetValue,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final progress = totalMax > 0 ? total / totalMax : 0.0;

    return SacCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: avatar + nombre + total
          Row(
            children: [
              _MemberAvatar(member: member),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.fullName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$total / $totalMax pts',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Barra de progreso total
          SacProgressBar(
            progress: progress.clamp(0.0, 1.0),
            height: 6,
            showShimmer: false,
            fillDuration: const Duration(milliseconds: 300),
          ),

          // Filas de categorías
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...categories.map((category) {
              final catPoints = scores[category.scoringCategoryId] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CategoryRow(
                  category: category,
                  points: catPoints,
                  isDisabled: isDisabled,
                  isReadOnly: isReadOnly,
                  onAdjust: (delta) =>
                      onAdjust(category.scoringCategoryId, delta),
                  onSetValue: (v) =>
                      onSetValue(category.scoringCategoryId, v),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Fila de una categoría con nombre, valor y botones de ajuste.
class _CategoryRow extends StatelessWidget {
  final ScoringCategory category;
  final int points;
  final bool isDisabled;
  final bool isReadOnly;
  final void Function(int delta) onAdjust;
  final void Function(int value) onSetValue;

  const _CategoryRow({
    required this.category,
    required this.points,
    required this.isDisabled,
    required this.isReadOnly,
    required this.onAdjust,
    required this.onSetValue,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      children: [
        // Nombre de la categoría
        Expanded(
          flex: 3,
          child: Text(
            category.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        const SizedBox(width: 8),

        if (isReadOnly) ...[
          // Solo lectura: mostrar valor sin controles
          Text(
            '$points / ${category.maxPoints}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ] else ...[
          // Controles: -1 | valor/max | +1
          Opacity(
            opacity: isDisabled ? 0.4 : 1.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SmallAdjustButton(
                  label: '-1',
                  isNegative: true,
                  isDisabled: isDisabled || points <= 0,
                  onPressed: () => onAdjust(-1),
                ),
                const SizedBox(width: 6),
                // Valor actual / max
                Container(
                  constraints: const BoxConstraints(minWidth: 52),
                  alignment: Alignment.center,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$points/${category.maxPoints}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 6),
                _SmallAdjustButton(
                  label: '+1',
                  isNegative: false,
                  isDisabled: isDisabled || points >= category.maxPoints,
                  onPressed: () => onAdjust(1),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Avatar circular con iniciales del miembro (o foto si tiene avatar).
class _MemberAvatar extends StatelessWidget {
  final UnitMember member;

  const _MemberAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    if (member.avatar != null) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(member.avatar!),
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        member.initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Botón pequeño de ajuste (+1 / -1) para cada categoría.
class _SmallAdjustButton extends StatelessWidget {
  final String label;
  final bool isNegative;
  final bool isDisabled;
  final VoidCallback onPressed;

  const _SmallAdjustButton({
    required this.label,
    required this.isNegative,
    required this.isDisabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final resolvedBg = isNegative ? c.surfaceVariant : AppColors.primaryLight;
    final resolvedFg = isNegative ? c.textSecondary : AppColors.primary;

    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              color: isDisabled
                  ? resolvedBg.withValues(alpha: 0.5)
                  : resolvedBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isDisabled
                      ? resolvedFg.withValues(alpha: 0.5)
                      : resolvedFg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Footer sticky con el botón de guardar y opción de resetear.
class _SaveFooter extends StatelessWidget {
  final bool isSavedToday;
  final VoidCallback onSave;
  final VoidCallback onReset;

  const _SaveFooter({
    required this.isSavedToday,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(color: c.border, width: 1),
        ),
      ),
      child: isSavedToday
          ? SacButton.outline(
              text: 'Reiniciar puntos',
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onReset,
            )
          : SacButton.primary(
              text: 'Guardar puntos del dia',
              icon: HugeIcons.strokeRoundedFloppyDisk,
              onPressed: onSave,
            ),
    );
  }
}
