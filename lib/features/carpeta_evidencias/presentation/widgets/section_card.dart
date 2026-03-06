import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/evidence_section.dart';
import 'section_status_badge.dart';

/// Tarjeta que resume una [EvidenceSection] en la vista de carpeta.
class SectionCard extends StatelessWidget {
  final EvidenceSection section;
  final VoidCallback onTap;

  const SectionCard({
    super.key,
    required this.section,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.name,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: c.text,
                                  ),
                        ),
                        if (section.description != null &&
                            section.description!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            section.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: c.textSecondary,
                                      height: 1.4,
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SectionStatusBadge(status: section.status),
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
                        '${section.earnedPoints} / ${section.pointValue} pts',
                    color: section.status == EvidenceSectionStatus.validado
                        ? AppColors.secondary
                        : c.textSecondary,
                    context: context,
                  ),
                  const SizedBox(width: 16),
                  _StatItem(
                    icon: HugeIcons.strokeRoundedPercent,
                    label: '${section.percentage.toStringAsFixed(1)}%',
                    color: c.textSecondary,
                    context: context,
                  ),
                  const SizedBox(width: 16),
                  _StatItem(
                    icon: HugeIcons.strokeRoundedFiles01,
                    label:
                        '${section.files.length} / ${section.maxFiles} archivos',
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
            if (section.submittedByName != null ||
                section.validatedByName != null) ...[
              Divider(height: 1, color: c.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (section.submittedByName != null)
                      _TraceRow(
                        icon: HugeIcons.strokeRoundedSent,
                        color: const Color(0xFF1D4ED8),
                        text:
                            'Enviado por ${section.submittedByName}${section.submittedAt != null ? " · ${dateFormat.format(section.submittedAt!)}" : ""}',
                        context: context,
                      ),
                    if (section.validatedByName != null) ...[
                      if (section.submittedByName != null)
                        const SizedBox(height: 4),
                      _TraceRow(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                        color: AppColors.secondary,
                        text:
                            'Validado por ${section.validatedByName}${section.validatedAt != null ? " · ${dateFormat.format(section.validatedAt!)}" : ""}',
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
}

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
