import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_requirement.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_with_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/requirement_track.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';

import '../utils/open_class_detail.dart';
import 'class_logo_box.dart';

/// Primer requisito de investidura que el miembro aún debe resolver.
///
/// Orden: módulos tal como llegan, luego `displayOrder` (los que no lo traen
/// van al final, conservando su orden). Se saltan los requisitos del tramo
/// avanzado y los que no cuentan para la investidura. «Por resolver» es
/// pendiente, rechazado u observado (enviado y validado no).
ClassRequirement? nextClassRequirement(ClassWithProgress classWithProgress) {
  for (final module in classWithProgress.modules) {
    final candidates = <ClassRequirement>[
      for (final requirement in module.requirements)
        if (requirement.requirementTrack != RequirementTrack.advanced &&
            requirement.requiredForInvestiture != false &&
            _isUnresolved(requirement.status))
          requirement,
    ];
    if (candidates.isEmpty) continue;

    var best = candidates.first;
    for (final candidate in candidates.skip(1)) {
      final bestOrder = best.displayOrder ?? 1 << 30;
      final candidateOrder = candidate.displayOrder ?? 1 << 30;
      if (candidateOrder < bestOrder) best = candidate;
    }
    return best;
  }
  return null;
}

bool _isUnresolved(RequirementStatus status) =>
    status == RequirementStatus.pendiente ||
    status == RequirementStatus.rechazado ||
    status == RequirementStatus.observado;

/// Tarjeta héroe «Mi clase» del inicio en modo miembro.
///
/// Porcentaje y conteo salen de la MISMA fuente: con
/// [classWithProgressProvider] cargado ambos usan validados / total para
/// investidura (porcentaje = piso de la razón); mientras carga muestra el
/// porcentaje del resumen del dashboard ([fallbackProgress]) y una línea
/// esqueleto para el conteo; si falla, solo el porcentaje del resumen.
///
/// Estados: completada (badge «Completada», botón «Ver mi clase»), vencida
/// (badge «Vencida», etiqueta «Clase vencida», botón «Ver mi clase»).
class ClassHeroCard extends ConsumerWidget {
  const ClassHeroCard({
    super.key,
    required this.currentClassName,
    this.currentClassId,
    this.fallbackProgress = 0.0,
    this.initialIsExpired = false,
  });

  final String currentClassName;
  final int? currentClassId;

  /// Progreso del resumen del dashboard (0.0-1.0), usado mientras carga o si
  /// el detalle falla.
  final double fallbackProgress;
  final bool initialIsExpired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final classId = currentClassId;
    final classState = classId != null
        ? ref.watch(
            classWithProgressProvider(ClassProgressQuery(classId: classId)),
          )
        : null;
    final loaded = classState?.value;
    final isLoading =
        classState != null && loaded == null && classState.isLoading;

    final total = loaded?.totalRequirementsForInvestiture ?? 0;
    final completed = loaded?.completedRequirementsForInvestiture ?? 0;
    final hasCounts = loaded != null && total > 0;

    final double progress;
    final int percent;
    if (hasCounts) {
      progress = (completed / total).clamp(0.0, 1.0);
      percent = (completed * 100 ~/ total).clamp(0, 100);
    } else if (loaded != null) {
      progress = loaded.completionRatio;
      percent = loaded.completionPercent;
    } else {
      progress = fallbackProgress.clamp(0.0, 1.0);
      percent = (progress * 100).floor();
    }

    final isExpired = initialIsExpired || (loaded?.isExpired ?? false);
    final isComplete = !isExpired && progress >= 1.0;
    final className = loaded?.name ?? currentClassName;
    final classColor = AppColors.classColor(className);
    final next = (loaded == null || isExpired || isComplete)
        ? null
        : nextClassRequirement(loaded);

    return SacCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClassLogoBox(
                className: className,
                imageUrl: loaded?.imageUrl,
                size: 60,
                padding: 8,
                radius: AppTheme.radiusMD,
                iconSize: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(isExpired
                          ? 'dashboard.class_card.expired_label'
                          : 'dashboard.class_hero.label'),
                      style: TextStyle(
                        fontSize: SacFontSize.labelSmall,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      className,
                      style: TextStyle(
                        fontSize: SacFontSize.headlineMedium,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _CountsLine(
                      hasCounts: hasCounts,
                      isLoading: isLoading,
                      completed: completed,
                      total: total,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isExpired)
                SacBadge.error(
                  label: tr('dashboard.class_card.expired_badge'),
                  icon: HugeIcons.strokeRoundedClock04,
                )
              else if (isComplete)
                SacBadge.success(
                  label: tr('dashboard.class_card.completed'),
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                )
              else
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: SacFontSize.headlineLarge,
                    fontWeight: FontWeight.w700,
                    color: c.onInfoContainer,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SacProgressBar(progress: progress, height: 8, color: classColor),
          if (next != null) ...[
            const SizedBox(height: 10),
            _NextRequirementRow(name: next.name),
          ],
          if (classId != null) ...[
            const SizedBox(height: 16),
            SacButton.primary(
              text: tr(
                isExpired || isComplete
                    ? 'dashboard.class_hero.view'
                    : 'dashboard.class_hero.continue',
              ),
              trailingIcon: HugeIcons.strokeRoundedArrowRight01,
              onPressed: () => openClassDetail(context, ref, classId),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountsLine extends StatelessWidget {
  const _CountsLine({
    required this.hasCounts,
    required this.isLoading,
    required this.completed,
    required this.total,
  });

  final bool hasCounts;
  final bool isLoading;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (hasCounts) {
      return Text(
        'dashboard.class_hero.requirements_count'.plural(
          total,
          args: ['$completed', '$total'],
        ),
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          color: context.sac.textSecondary,
        ),
      );
    }
    if (isLoading) {
      return const SacSkeletonBox(width: 110, height: 13);
    }
    return const SizedBox.shrink();
  }
}

class _NextRequirementRow extends StatelessWidget {
  const _NextRequirementRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = TextStyle(
      fontSize: SacFontSize.bodySmall,
      color: c.textSecondary,
    );
    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedTarget02,
          size: 16,
          color: c.textSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(text: '${tr('dashboard.class_hero.next')} '),
                TextSpan(
                  text: name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
