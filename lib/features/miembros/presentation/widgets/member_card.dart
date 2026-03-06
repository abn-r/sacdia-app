import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';

import '../../domain/entities/club_member.dart';

/// Tarjeta de miembro del club que muestra foto, nombre, cargo y estado
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

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Avatar ────────────────────────────────────────────────
              _MemberAvatar(member: member),

              const SizedBox(width: 12),

              // ── Info ──────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      member.fullName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Role / Cargo
                    if (member.clubRole != null) ...[
                      Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedLabel,
                            color: c.textTertiary,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              RoleUtils.translate(member.clubRole),
                              style: TextStyle(
                                fontSize: 12,
                                color: c.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Class + Enrollment status
                    Row(
                      children: [
                        if (member.currentClass != null) ...[
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedSchool,
                                  color: c.textTertiary,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    member.currentClass!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _EnrollmentBadge(isEnrolled: member.isEnrolled),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Actions ───────────────────────────────────────────────
              if (onAssignRole != null) ...[
                const SizedBox(width: 8),
                _AssignRoleButton(onTap: onAssignRole!),
              ] else ...[
                const SizedBox(width: 8),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: c.textTertiary,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar circular del miembro con fallback de iniciales
class _MemberAvatar extends StatelessWidget {
  final ClubMember member;

  const _MemberAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primaryLight,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primarySurface,
        backgroundImage:
            member.avatar != null ? NetworkImage(member.avatar!) : null,
        child: member.avatar == null
            ? Text(
                member.initials,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              )
            : null,
      ),
    );
  }
}

/// Badge de estado de inscripción
class _EnrollmentBadge extends StatelessWidget {
  final bool isEnrolled;

  const _EnrollmentBadge({required this.isEnrolled});

  @override
  Widget build(BuildContext context) {
    if (isEnrolled) {
      return const SacBadge.success(label: 'Inscrito');
    }
    return SacBadge(
      label: 'No inscrito',
      variant: SacBadgeVariant.neutral,
    );
  }
}

/// Botón para asignar rol al miembro
class _AssignRoleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AssignRoleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedUserEdit01,
            color: AppColors.primary,
            size: 18,
          ),
        ),
      ),
    );
  }
}
