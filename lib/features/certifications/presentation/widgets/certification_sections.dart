import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/certification_module.dart';
import '../../domain/entities/certification_progress.dart';
import '../../domain/entities/certification_status.dart';
import '../utils/certification_status_view.dart';
import 'certification_module_row.dart';
import 'certification_requirement_row.dart';

/// «Por atender»: what was sent back first, then what is started but not
/// sent. Nothing is drawn when there is nothing to attend.
class CertificationAttentionSection extends StatelessWidget {
  const CertificationAttentionSection({
    super.key,
    required this.modules,
    required this.onOpenRequirement,
  });

  final List<ModuleProgress> modules;
  final void Function(SectionProgress section) onOpenRequirement;

  @override
  Widget build(BuildContext context) {
    final entries = attentionSections(modules);
    if (entries.isEmpty) return const SizedBox.shrink();
    return SacGroupedSection(
      key: const ValueKey('certification-attention-section'),
      label: 'certifications.view.group_attention'.tr(),
      count: entries.length,
      rollCount: true,
      children: [
        for (final (_, section) in entries)
          CertificationRequirementRow(
            section: section,
            onTap: () => onOpenRequirement(section),
          ),
      ],
    );
  }
}

/// «Módulos · 8»: one row per module, no accordions. The module screen lists
/// its requirements.
class CertificationModulesSection extends StatelessWidget {
  const CertificationModulesSection({
    super.key,
    required this.modules,
    required this.onOpenModule,
  });

  final List<ModuleProgress> modules;
  final void Function(ModuleProgress module) onOpenModule;

  @override
  Widget build(BuildContext context) {
    return SacGroupedSection(
      key: const ValueKey('certification-modules-section'),
      label: 'certifications.view.modules_title'.tr(),
      children: [
        for (final m in modules)
          CertificationModuleRow(
            key: ValueKey('certification-module-${m.moduleId}'),
            moduleId: m.moduleId,
            name: m.moduleName,
            counts: countSections(m.sections),
            onTap: () => onOpenModule(m),
          ),
      ],
    );
  }
}

/// The modules of a certification the person is not enrolled in: name and
/// «N requisitos»; each opens the module read-only.
class CertificationCatalogModulesSection extends StatelessWidget {
  const CertificationCatalogModulesSection({
    super.key,
    required this.modules,
    required this.onOpenModule,
  });

  final List<CertificationModule> modules;
  final void Function(CertificationModule module) onOpenModule;

  @override
  Widget build(BuildContext context) {
    return SacGroupedSection(
      key: const ValueKey('certification-modules-section'),
      label: 'certifications.view.modules_title'.tr(),
      children: [
        for (final m in modules)
          CertificationModuleRow(
            key: ValueKey('certification-module-${m.moduleId}'),
            moduleId: m.moduleId,
            name: m.name,
            plainDetail:
                'certifications.common.requirements'.plural(m.sections.length),
            onTap: () => onOpenModule(m),
          ),
      ],
    );
  }
}

/// «Cierre»: the board record as one more row. Locked until every
/// requirement is validated; then it opens the closeout.
class CertificationCloseoutSection extends StatelessWidget {
  const CertificationCloseoutSection({
    super.key,
    required this.status,
    required this.requirementsTotal,
    required this.onOpen,
  });

  final CertificationEnrollmentStatus status;
  final int requirementsTotal;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (status == CertificationEnrollmentStatus.expired ||
        status == CertificationEnrollmentStatus.withdrawn) {
      return const SizedBox.shrink();
    }
    final c = context.sac;
    final title = 'certifications.closeout.title'.tr();

    final SacStatusKind kind;
    final String detail;
    var locked = false;
    switch (status) {
      case CertificationEnrollmentStatus.readyForCloseout:
        kind = SacStatusKind.pending;
        detail = 'certifications.view.closeout_ready'.tr();
      case CertificationEnrollmentStatus.changesRequested:
        kind = SacStatusKind.rejected;
        detail = 'certifications.view.closeout_changes'.tr();
      case CertificationEnrollmentStatus.submittedForFinalReview:
        kind = SacStatusKind.review;
        detail = 'certifications.closeout.state_review'.tr();
      case CertificationEnrollmentStatus.approved:
      case CertificationEnrollmentStatus.certified:
        kind = SacStatusKind.validated;
        detail = 'certifications.status.validated'.tr();
      default:
        locked = true;
        kind = SacStatusKind.pending;
        detail =
            'certifications.view.closeout_locked'.plural(requirementsTotal);
    }

    final style = SacStatusStyle.of(
      context,
      kind,
      label: locked
          ? 'certifications.view.closeout_locked_label'.tr()
          : certificationKindLabel(kind),
      icon: locked ? HugeIcons.strokeRoundedLockKey : null,
    );

    return SacGroupedSection(
      key: const ValueKey('certification-closeout-section'),
      label: 'certifications.view.closeout_group'.tr(),
      count: 1,
      children: [
        Semantics(
          container: true,
          button: !locked,
          excludeSemantics: true,
          onTap: locked ? null : onOpen,
          label: '$title. ${style.label}. $detail',
          child: IgnorePointer(
            ignoring: locked,
            child: SacStatusRow(
              key: const ValueKey('certification-closeout-row'),
              style: style,
              title: title,
              detail: detail,
              detailIsError: kind == SacStatusKind.rejected,
              onTap: onOpen,
              trailing: locked
                  ? SizedBox(
                      width: 18,
                      child: ExcludeSemantics(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedLockKey,
                          size: 16,
                          color: c.textTertiary,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// «Descargar certificado» of a certified enrollment.
class CertificationDownloadSection extends StatelessWidget {
  const CertificationDownloadSection({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = SacStatusStyle.of(
      context,
      SacStatusKind.validated,
      label: 'certifications.view.download_certificate'.tr(),
      icon: HugeIcons.strokeRoundedDownload01,
    );
    return SacGroupedSection(
      key: const ValueKey('certification-download-section'),
      label: 'certifications.view.certificate_group'.tr(),
      count: 1,
      children: [
        Semantics(
          container: true,
          button: true,
          excludeSemantics: true,
          onTap: onTap,
          label: style.label,
          child: SacStatusRow(
            key: const ValueKey('certification-download-row'),
            style: style,
            title: style.label,
            detail: 'certifications.view.download_hint'.tr(),
            onTap: onTap,
            trailing: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowUpRight01,
              size: 18,
              color: c.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

/// One rule of «Requisitos de inscripción»: a check when met, a clock when
/// not yet. Read-only.
class CertificationRuleRow extends StatelessWidget {
  const CertificationRuleRow({
    super.key,
    required this.title,
    required this.satisfied,
  });

  final String title;
  final bool satisfied;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final kind = satisfied ? SacStatusKind.validated : SacStatusKind.pending;
    final detail = satisfied
        ? 'certifications.eligibility.met'.tr()
        : 'certifications.eligibility.not_met'.tr();
    final style = SacStatusStyle.of(
      context,
      kind,
      label: detail,
      icon: satisfied
          ? HugeIcons.strokeRoundedCheckmarkCircle02
          : HugeIcons.strokeRoundedClock01,
    );
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$title. $detail',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.container,
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: style.icon,
                  size: 17,
                  color: style.onContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
