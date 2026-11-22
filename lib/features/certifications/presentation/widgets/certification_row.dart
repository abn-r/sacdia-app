import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../domain/entities/certification_status.dart';
import 'certification_header.dart';

/// Tone of the status chip of a certification row.
enum CertificationChipTone { available, inProgress, review, certified, alert }

CertificationChipTone certificationChipTone(CertificationEnrollmentStatus s) {
  switch (s) {
    case CertificationEnrollmentStatus.enrolled:
    case CertificationEnrollmentStatus.inProgress:
    case CertificationEnrollmentStatus.readyForCloseout:
      return CertificationChipTone.inProgress;
    case CertificationEnrollmentStatus.submittedForFinalReview:
      return CertificationChipTone.review;
    case CertificationEnrollmentStatus.approved:
    case CertificationEnrollmentStatus.certified:
      return CertificationChipTone.certified;
    case CertificationEnrollmentStatus.changesRequested:
    case CertificationEnrollmentStatus.expired:
      return CertificationChipTone.alert;
    case CertificationEnrollmentStatus.withdrawn:
      return CertificationChipTone.available;
  }
}

/// A certification as a row: icon tile, short name, «N módulos» and its
/// status chip. The same row in Mis clases and in the catalog, built like a
/// club class row.
class CertificationRow extends StatelessWidget {
  const CertificationRow({
    super.key,
    required this.name,
    required this.chipLabel,
    required this.chipTone,
    required this.onTap,
    this.meta,
  });

  final String name;
  final String? meta;
  final String chipLabel;
  final CertificationChipTone chipTone;
  final VoidCallback onTap;

  Widget _chip() {
    switch (chipTone) {
      case CertificationChipTone.available:
        return SacBadge(label: chipLabel, variant: SacBadgeVariant.neutral);
      case CertificationChipTone.inProgress:
        return SacBadge(label: chipLabel);
      case CertificationChipTone.review:
        return SacBadge.info(label: chipLabel);
      case CertificationChipTone.certified:
        return SacBadge.success(label: chipLabel);
      case CertificationChipTone.alert:
        return SacBadge.error(label: chipLabel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final meta = this.meta;
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: [name, if (meta != null && meta.isNotEmpty) meta, chipLabel]
          .join('. '),
      onTap: onTap,
      child: SacInkWell(
        onTap: onTap,
        pressedScale: SacMotion.rowPressScale,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                const CertificationIconTile(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      if (meta != null && meta.isNotEmpty)
                        Text(
                          meta,
                          style: TextStyle(
                            fontSize: SacFontSize.bodySmall,
                            color: c.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _chip(),
                const SizedBox(width: 6),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
