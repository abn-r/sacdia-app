import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/role_candidate.dart';
import '../utils/role_candidate_labels.dart';

/// Row of the «Agregar directivo» list: avatar, name, subtitle and the tags of
/// the person's Guía Mayor standing.
///
/// - Actionable (`allowed_roles` not empty, consent ok): whole row taps and
///   shows a chevron.
/// - Holds a role in THIS section: dimmed and inert, subtitle says «(esta sección)».
/// - Consent missing / not enrolled: inert, subtitle explains why in the
///   warning tone.
class RoleCandidateRow extends StatelessWidget {
  const RoleCandidateRow({
    super.key,
    required this.candidate,
    required this.sectionId,
    this.onTap,
  });

  final RoleCandidate candidate;

  /// Section that would receive the role (decides «(esta sección)»).
  final int sectionId;

  /// `null` makes the row inert.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final subtitle = roleCandidateSubtitle(candidate, sectionId);
    final heldHere = candidate.holdsRoleInSection(sectionId);
    final isWarning = !heldHere &&
        (candidate.isConsentMissing ||
            candidate.group == RoleCandidateGroup.notEnrolled ||
            candidate.blockedReason ==
                RoleCandidateBlockedReason.gmMembershipRequired ||
            (candidate.currentRoles.isEmpty && candidate.allowedRoles.isEmpty));
    final tags = guideMajorTags(candidate.guideMajor);

    Widget row = SacPressable(
      onTap: onTap,
      enabled: onTap != null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SacMemberAvatar(
                imageUrl: candidate.photoUrl,
                name: candidate.name,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      candidate.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.titleSmall,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: isWarning
                              ? c.onWarningContainer
                              : c.textSecondary,
                          fontWeight:
                              isWarning ? FontWeight.w600 : FontWeight.w400,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      RoleCandidateTags(guideMajor: candidate.guideMajor),
                    ],
                    if (candidate.hasFlaggedRequirement) ...[
                      const SizedBox(height: 6),
                      const RoleCandidateRequirementChip(),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    row = MergeSemantics(child: row);
    return heldHere ? Opacity(opacity: 0.55, child: row) : row;
  }
}

/// Tags of a person's Guía Mayor standing: the investiture basis follows the
/// accent, «Avanzado» / «Instructor» stay neutral.
class RoleCandidateTags extends StatelessWidget {
  const RoleCandidateTags({super.key, required this.guideMajor});

  final RoleCandidateGuideMajor? guideMajor;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final tags = guideMajorTags(guideMajor);
    final hasBasis = guideMajorBasisLabel(guideMajor) != null;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (var i = 0; i < tags.length; i++)
          DecoratedBox(
            decoration: BoxDecoration(
              color: i == 0 && hasBasis ? accent.light : c.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Text(
                tags[i],
                style: TextStyle(
                  fontSize: SacFontSize.labelSmall,
                  fontWeight: FontWeight.w600,
                  color: i == 0 && hasBasis ? accent.dark : c.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// «Sin constancia» chip in the warning tones (WARN / BLOCK requirements only).
class RoleCandidateRequirementChip extends StatelessWidget {
  const RoleCandidateRequirementChip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return DecoratedBox(
      key: const ValueKey('requirement-chip'),
      decoration: BoxDecoration(
        color: c.warningContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: 12,
                color: c.onWarningContainer,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'members.role_candidates.credential.chip_missing'.tr(),
                style: TextStyle(
                  fontSize: SacFontSize.labelSmall,
                  fontWeight: FontWeight.w600,
                  color: c.onWarningContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
