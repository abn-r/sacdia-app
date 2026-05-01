import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/role_utils.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/section_switcher_sheet.dart';
import '../../../auth/domain/entities/authorization_snapshot.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../club/presentation/providers/club_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// Card que muestra el club/sección activo y permite cambiar de contexto.
///
/// Solo se renderiza cuando el usuario tiene al menos un assignment en su
/// AuthorizationSnapshot. Si tiene un único assignment, el tap abre el sheet
/// pero sin opción de cambio (solo informativo con el checkmark activo).
class ClubContextCard extends ConsumerWidget {
  const ClubContextCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    final authorization = user?.authorization;

    // No renderizar si no hay assignments
    final assignments = authorization?.clubAssignments ?? const [];
    if (assignments.isEmpty) return const SizedBox.shrink();

    final activeGrant = authorization?.activeGrant;
    final userGender = ref.watch(
      profileNotifierProvider.select((v) => v.valueOrNull?.gender),
    );
    final activeRoleName = RoleUtils.translate(
      activeGrant?.roleName,
      gender: userGender,
    );

    // Try to get the club type name from the section data
    final sectionAsync = ref.watch(currentClubSectionProvider);
    final clubTypeName = sectionAsync.valueOrNull?.clubTypeName ?? tr('home.club_context.default_club_type');

    final c = context.sac;

    // Determine accent color based on membership status.
    final Color accentColor;
    if (activeGrant != null && activeGrant.isPending) {
      accentColor = AppColors.accent;
    } else if (activeGrant != null && activeGrant.isRejected) {
      accentColor = AppColors.error;
    } else if (activeGrant != null && activeGrant.isExpired) {
      accentColor = c.textTertiary;
    } else {
      accentColor = AppColors.primary;
    }

    return SacCard(
      accentColor: accentColor,
      onTap: () {
        showSectionSwitcher(
          context: context,
          ref: ref,
          assignments: assignments,
          activeAssignmentId: authorization?.activeAssignmentId,
          userGender: userGender,
        );
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedUserGroup,
                color: accentColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        clubTypeName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (activeGrant != null && !activeGrant.isActive) ...[
                      const SizedBox(width: 8),
                      _MembershipStatusBadge(grant: activeGrant),
                    ],
                  ],
                ),
                if (activeRoleName.isNotEmpty)
                  Text(
                    activeRoleName,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (assignments.length > 1)
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowUpDown,
              color: c.textTertiary,
              size: 20,
            ),
        ],
      ),
    );
  }
}

/// Small colored badge indicating the membership status of an assignment.
class _MembershipStatusBadge extends StatelessWidget {
  final AuthorizationGrant grant;

  const _MembershipStatusBadge({required this.grant});

  @override
  Widget build(BuildContext context) {
    final (String label, Color bg, Color fg) = switch (grant.status) {
      'pending' => (tr('home.club_context.status_pending'), AppColors.accentLight, AppColors.accentDark),
      'rejected' => (tr('home.club_context.status_rejected'), AppColors.errorLight, AppColors.errorDark),
      'expired' => (tr('home.club_context.status_expired'), AppColors.lightBorderLight, AppColors.lightTextSecondary),
      _ => ('', Colors.transparent, Colors.transparent),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
