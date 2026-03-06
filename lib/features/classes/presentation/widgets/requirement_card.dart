import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/class_requirement.dart';
import 'requirement_status_badge.dart';

/// Tarjeta que resume un [ClassRequirement] en la vista de clase.
///
/// Sigue el patron identico al SectionCard de carpeta_evidencias.
class RequirementCard extends StatelessWidget {
  final ClassRequirement requirement;
  final VoidCallback onTap;

  const RequirementCard({
    super.key,
    required this.requirement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'es');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icono del tipo de requerimiento
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _typeColor(requirement.type)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: HugeIcon(
                      icon: _typeIcon(requirement.type),
                      size: 18,
                      color: _typeColor(requirement.type),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requirement.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: c.text,
                              ),
                        ),
                        if (requirement.description != null &&
                            requirement.description!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            requirement.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: c.textSecondary,
                                  height: 1.4,
                                ),
                          ),
                        ],
                        if (requirement.type == RequirementType.honor &&
                            requirement.linkedHonorName != null) ...[
                          const SizedBox(height: 4),
                          _HonorBadge(
                            name: requirement.linkedHonorName!,
                            completed:
                                requirement.linkedHonorCompleted ?? false,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  RequirementStatusBadge(status: requirement.status),
                ],
              ),
            ),

            Divider(height: 1, color: c.divider),

            // Stats row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  _StatItem(
                    icon: HugeIcons.strokeRoundedStar,
                    label:
                        '${requirement.earnedPoints} / ${requirement.pointValue} pts',
                    color: requirement.status == RequirementStatus.validado
                        ? AppColors.secondary
                        : c.textSecondary,
                    context: context,
                  ),
                  const SizedBox(width: 16),
                  _StatItem(
                    icon: HugeIcons.strokeRoundedFiles01,
                    label:
                        '${requirement.files.length} / ${requirement.maxFiles} archivos',
                    color: c.textSecondary,
                    context: context,
                  ),
                  const Spacer(),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                    color: c.textTertiary,
                  ),
                ],
              ),
            ),

            // Trazabilidad (si aplica)
            if (requirement.submittedByName != null ||
                requirement.validatedByName != null) ...[
              Divider(height: 1, color: c.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (requirement.submittedByName != null)
                      _TraceRow(
                        icon: HugeIcons.strokeRoundedSent,
                        color: const Color(0xFF1D4ED8),
                        text:
                            'Enviado por ${requirement.submittedByName}${requirement.submittedAt != null ? " · ${dateFormat.format(requirement.submittedAt!)}" : ""}',
                        context: context,
                      ),
                    if (requirement.validatedByName != null) ...[
                      if (requirement.submittedByName != null)
                        const SizedBox(height: 4),
                      _TraceRow(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                        color: AppColors.secondary,
                        text:
                            'Validado por ${requirement.validatedByName}${requirement.validatedAt != null ? " · ${dateFormat.format(requirement.validatedAt!)}" : ""}',
                        context: context,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _typeColor(RequirementType type) {
    switch (type) {
      case RequirementType.honor:
        return AppColors.sacBlue;
      case RequirementType.service:
        return AppColors.secondary;
      case RequirementType.general:
        return AppColors.primary;
    }
  }

  List<List<dynamic>> _typeIcon(RequirementType type) {
    switch (type) {
      case RequirementType.honor:
        return HugeIcons.strokeRoundedAward01;
      case RequirementType.service:
        return HugeIcons.strokeRoundedCharity;
      case RequirementType.general:
        return HugeIcons.strokeRoundedCheckList;
    }
  }
}

// ── Honor badge ────────────────────────────────────────────────────────────────

class _HonorBadge extends StatelessWidget {
  final String name;
  final bool completed;

  const _HonorBadge({required this.name, required this.completed});

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppColors.secondary : AppColors.sacBlue;
    final bgColor = completed
        ? AppColors.secondaryLight
        : const Color(0xFFEFF6FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: completed
                ? HugeIcons.strokeRoundedCheckmarkCircle01
                : HugeIcons.strokeRoundedAward01,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final Color color;
  final BuildContext context;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _TraceRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color color;
  final String text;
  final BuildContext context;

  const _TraceRow({
    required this.icon,
    required this.color,
    required this.text,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 12, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  height: 1.3,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
