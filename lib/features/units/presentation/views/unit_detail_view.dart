import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';

import '../../domain/entities/unit.dart';
import '../../domain/entities/unit_member.dart';
import '../providers/units_providers.dart';

/// Vista de detalle de una unidad: lista de miembros con control de puntos diarios.
///
/// Muestra:
/// - Header con info de la unidad
/// - Banner de "ya registrado hoy" si [isSavedToday]
/// - Lista de miembros con botones +5 / +1 / -1 / -5
/// - Footer sticky con botón de guardar
class UnitDetailView extends ConsumerWidget {
  final Unit unit;

  const UnitDetailView({super.key, required this.unit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(unitsNotifierProvider);
    final notifier = ref.read(unitsNotifierProvider.notifier);
    final c = context.sac;

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
                    'Puntos del día',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: c.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),

                // Lista de miembros
                ...state.members.map((member) {
                  final points = state.pendingPoints[member.id] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MemberPointsRow(
                      member: member,
                      points: points,
                      maxPoints: state.maxPoints,
                      isDisabled: state.isSavedToday,
                      onAdjust: (delta) {
                        notifier.adjustPoints(member.id, delta);
                      },
                    ),
                  );
                }),

                // Padding inferior para que el footer no tape el último item
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Footer sticky ─────────────────────────────────────────
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
    final saved = notifier.saveSession();
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes asignar puntos a todos los miembros o a ninguno',
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

/// Fila de un miembro con avatar, nombre, barra de progreso y botones de ajuste.
class _MemberPointsRow extends StatelessWidget {
  final UnitMember member;
  final int points;
  final int maxPoints;
  final bool isDisabled;
  final void Function(int delta) onAdjust;

  const _MemberPointsRow({
    required this.member,
    required this.points,
    required this.maxPoints,
    required this.isDisabled,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final progress = maxPoints > 0 ? points / maxPoints : 0.0;

    return SacCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: avatar + nombre + valor de puntos
          Row(
            children: [
              // Avatar con iniciales
              _MemberAvatar(member: member),
              const SizedBox(width: 12),

              // Nombre
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

              // Puntos actuales
              Text(
                '$points / $maxPoints pts',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Barra de progreso
          SacProgressBar(
            progress: progress,
            height: 6,
            showShimmer: false,
            fillDuration: const Duration(milliseconds: 300),
          ),

          const SizedBox(height: 12),

          // Fila de botones: -5 | -1 | valor | +1 | +5
          Opacity(
            opacity: isDisabled ? 0.4 : 1.0,
            child: Row(
              children: [
                _PointButton(
                  label: '-5',
                  isNegative: true,
                  isDisabled: isDisabled || points == 0,
                  onPressed: () => onAdjust(-5),
                ),
                const SizedBox(width: 6),
                _PointButton(
                  label: '-1',
                  isNegative: true,
                  isDisabled: isDisabled || points == 0,
                  onPressed: () => onAdjust(-1),
                ),
                const Spacer(),
                Container(
                  constraints: const BoxConstraints(minWidth: 44),
                  alignment: Alignment.center,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$points',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const Spacer(),
                _PointButton(
                  label: '+1',
                  isNegative: false,
                  isDisabled: isDisabled || points >= maxPoints,
                  onPressed: () => onAdjust(1),
                ),
                const SizedBox(width: 6),
                _PointButton(
                  label: '+5',
                  isNegative: false,
                  isDisabled: isDisabled || points >= maxPoints,
                  onPressed: () => onAdjust(5),
                ),
              ],
            ),
          ),
        ],
      ),
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
        backgroundImage: NetworkImage(member.avatar!),
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

/// Botón de ajuste de puntos (+5, +1, -1, -5).
///
/// Touch target garantizado de 44dp via [SizedBox].
class _PointButton extends StatelessWidget {
  final String label;
  final bool isNegative;
  final bool isDisabled;
  final VoidCallback onPressed;

  const _PointButton({
    required this.label,
    required this.isNegative,
    required this.isDisabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final resolvedBg =
        isNegative ? c.surfaceVariant : AppColors.primaryLight;
    final resolvedFg =
        isNegative ? c.textSecondary : AppColors.primary;

    return SizedBox(
      width: 52,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: isDisabled
                  ? resolvedBg.withValues(alpha: 0.5)
                  : resolvedBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isDisabled
                      ? resolvedFg.withValues(alpha: 0.5)
                      : resolvedFg,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
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
