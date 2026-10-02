import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_profile_image.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/club_member.dart';

/// Compact roster row: name + one meta line. Class label lives on the group header.
class MemberCard extends StatelessWidget {
  final ClubMember member;
  final VoidCallback? onTap;
  final VoidCallback? onAssignRole;

  const MemberCard({
    super.key,
    required this.member,
    this.onTap,
    this.onAssignRole,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final displayClass = _displayClass(member);
    final classLogoAsset =
        displayClass == null ? null : AppColors.classLogoAsset(displayClass);
    final roleLabel = member.clubRole == null
        ? null
        : RoleUtils.translate(member.clubRole, gender: member.gender);
    final showNotEnrolled = !member.isEnrolled;
    final hasClassMark = displayClass != null;

    return SacPressable(
      onTap: onTap,
      enabled: onTap != null,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _MemberAvatar(member: member),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    member.fullName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasClassMark || roleLabel != null || showNotEnrolled) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (hasClassMark) ...[
                          if (classLogoAsset != null)
                            Image.asset(
                              classLogoAsset,
                              key: ValueKey(
                                'member-card-class-logo-$displayClass',
                              ),
                              width: 16,
                              height: 16,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            )
                          else
                            HugeIcon(
                              key: const ValueKey(
                                'member-card-class-fallback-icon',
                              ),
                              icon: HugeIcons.strokeRoundedSchool,
                              color: c.textTertiary,
                              size: 13,
                            ),
                          if (roleLabel != null || showNotEnrolled)
                            const SizedBox(width: 6),
                        ],
                        if (roleLabel != null)
                          Flexible(
                            child: Text(
                              roleLabel,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                color: c.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (showNotEnrolled) ...[
                          if (roleLabel != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '·',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textTertiary,
                                ),
                              ),
                            ),
                          _EnrollmentBadge(isEnrolled: member.isEnrolled),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onAssignRole != null) ...[
              const SizedBox(width: 4),
              _AssignRoleButton(onTap: onAssignRole!),
            ] else ...[
              const SizedBox(width: 4),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: c.textTertiary,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _displayClass(ClubMember member) {
  final sectionClass = member.currentClass?.trim();
  if (sectionClass != null && sectionClass.isNotEmpty) return sectionClass;
  if (!member.hasGuideMajorClass || !member.isSectionBoard) return null;
  final guideMajor = member.guideMajorClassName?.trim();
  if (guideMajor != null && guideMajor.isNotEmpty) return guideMajor;
  return 'members.guide_majors_group'.tr();
}

class _MemberAvatar extends StatelessWidget {
  final ClubMember member;

  const _MemberAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: SacAccent.of(context).light,
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: SizedBox(
          width: 36,
          height: 36,
          child: member.avatar != null
              ? SacProfileImage(
                  imageUrl: member.avatar!,
                  fit: BoxFit.cover,
                  memCacheWidth: 72,
                  memCacheHeight: 72,
                  placeholder: (_, __) => _AvatarInitials(
                    initials: member.initials,
                  ),
                  errorWidget: (_, __, ___) => _AvatarInitials(
                    initials: member.initials,
                  ),
                )
              : _AvatarInitials(initials: member.initials),
        ),
      ),
    );
  }
}

class _EnrollmentBadge extends StatelessWidget {
  final bool isEnrolled;

  const _EnrollmentBadge({required this.isEnrolled});

  @override
  Widget build(BuildContext context) {
    if (isEnrolled) {
      return const SizedBox.shrink();
    }
    return SacBadge(
      label: 'members.common.not_enrolled'.tr(),
      variant: SacBadgeVariant.neutral,
    );
  }
}

class _AssignRoleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AssignRoleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SacPressable(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: SacAccent.of(context).color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedUserEdit01,
                color: SacAccent.of(context).color,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  final String initials;

  const _AvatarInitials({required this.initials});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
