import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/evidence_section.dart';
import 'section_status_badge.dart';

/// Tarjeta que resume una [EvidenceSection] en la vista de carpeta.
///
/// Cuando [folderIsOpen] es true y la sección tiene [EvidenceSection.canSubmit]
/// en true, muestra un botón "Enviar a validación" que invoca [onSubmit].
class SectionCard extends StatelessWidget {
  final EvidenceSection section;
  final VoidCallback onTap;

  /// Si la carpeta está abierta. Controla visibilidad del botón de envío.
  final bool folderIsOpen;

  /// Callback opcional para enviar la sección a validación.
  ///
  /// Si es null o [folderIsOpen] es false, el botón no se muestra.
  final VoidCallback? onSubmit;

  /// Indica si el envío de esta sección está en progreso.
  ///
  /// Cuando es true, el botón muestra un estado de carga.
  final bool isSubmitting;

  const SectionCard({
    super.key,
    required this.section,
    required this.onTap,
    this.folderIsOpen = true,
    this.onSubmit,
    this.isSubmitting = false,
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
              color: c.shadow,
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
                    color: section.status == EvidenceSectionStatus.validado ||
                            section.status == EvidenceSectionStatus.evaluated
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
                section.validatedByName != null ||
                section.evaluatedByName != null) ...[
              Divider(height: 1, color: c.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (section.submittedByName != null)
                      _TraceRow(
                        icon: HugeIcons.strokeRoundedSent,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.statusInfoTextDark
                            : AppColors.statusInfoText,
                        text:
                            'Enviado por ${section.submittedByName}${section.submittedAt != null ? " · ${dateFormat.format(section.submittedAt!.toLocal())}" : ""}',
                        context: context,
                      ),
                    if (section.validatedByName != null) ...[
                      if (section.submittedByName != null)
                        const SizedBox(height: 4),
                      _TraceRow(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                        color: AppColors.secondary,
                        text:
                            'Validado por ${section.validatedByName}${section.validatedAt != null ? " · ${dateFormat.format(section.validatedAt!.toLocal())}" : ""}',
                        context: context,
                      ),
                    ],
                    if (section.evaluatedByName != null) ...[
                      if (section.submittedByName != null ||
                          section.validatedByName != null)
                        const SizedBox(height: 4),
                      _TraceRow(
                        icon: HugeIcons.strokeRoundedStar,
                        color: AppColors.secondaryDark,
                        text:
                            'Evaluado por ${section.evaluatedByName}${section.evaluatedAt != null ? " · ${dateFormat.format(section.evaluatedAt!.toLocal())}" : ""}',
                        context: context,
                      ),
                    ],
                    if (section.evaluationNotes != null &&
                        section.evaluationNotes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          section.evaluationNotes!,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.secondaryDark,
                                    height: 1.4,
                                  ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Botón de envío a validación (solo cuando la sección puede enviarse)
            if (folderIsOpen && section.canSubmit && onSubmit != null) ...[
              Divider(height: 1, color: c.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: _SubmitSectionButton(
                  isSubmitting: isSubmitting,
                  onSubmit: onSubmit!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Botón de envío a validación dentro de la tarjeta de sección.
///
/// Muestra un estado de carga cuando [isSubmitting] es true y llama
/// a [onSubmit] al ser presionado.
class _SubmitSectionButton extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _SubmitSectionButton({
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSubmitting ? null : onSubmit,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: isSubmitting
                  ? AppColors.sacBlue.withValues(alpha: 0.08)
                  : AppColors.sacBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.sacBlue.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSubmitting) ...[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.sacBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Enviando...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sacBlue,
                      ),
                    ),
                  ] else ...[
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedSent,
                      size: 15,
                      color: AppColors.sacBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Enviar a validación',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sacBlue,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
