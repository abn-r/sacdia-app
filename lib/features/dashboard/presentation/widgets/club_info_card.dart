import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/section_switcher_sheet.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// Card de información del club - Estilo "Scout Vibrante"
///
/// SacCard con barra de acento lateral del color del club,
/// badges para tipo y rol, icono de grupo.
///
/// Club type and role are derived from the auth state's active grant (the same
/// source the section switcher sheet uses) so the card and the sheet always
/// agree on which section is active. [clubName] is the only prop still taken
/// from the dashboard summary, since the grant does not include it.
///
/// Cuando el usuario tiene más de un club asignado, el tap abre el
/// [showSectionSwitcher] bottom sheet personalizado para cambiar de sección.
/// Con un único assignment el chevron es decorativo y el tap no hace nada.
class ClubInfoCard extends ConsumerWidget {
  final String? clubName;

  /// Fallback club type from dashboard summary. Used only when the active grant
  /// does not have a [clubTypeName] (should not happen in practice).
  final String? clubType;

  /// Fallback role from dashboard summary. Used only when the active grant does
  /// not have a [roleName].
  final String? userRole;

  const ClubInfoCard({
    super.key,
    this.clubName,
    this.clubType,
    this.userRole,
  });

  Color _getClubColor(String? type) {
    if (type == null) return AppColors.primary;
    final lower = type.toLowerCase();
    if (lower.contains('conquistador')) return AppColors.primary;
    if (lower.contains('aventurer')) return AppColors.sacBlue;
    if (lower.contains('guía') || lower.contains('guia')) return AppColors.secondary;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final authorization = authState.valueOrNull?.authorization;
    final assignments = authorization?.clubAssignments ?? const [];
    final hasMultiple = assignments.length > 1;
    final activeGrant = authorization?.activeGrant;

    // Derive club type and role from the active grant (same source as the
    // section switcher sheet) so card and sheet always agree. Fall back to
    // dashboard-summary props only when the grant is unavailable.
    final resolvedClubType = activeGrant?.clubTypeName ?? clubType;
    final userGender = ref.watch(
      profileNotifierProvider.select((v) => v.valueOrNull?.gender),
    );
    final resolvedRole = activeGrant?.roleName != null
        ? RoleUtils.translate(activeGrant!.roleName, gender: userGender)
        : userRole;

    final clubColor = _getClubColor(resolvedClubType);

    return SacCard(
      accentColor: clubColor,
      onTap: hasMultiple
          ? () {
              showSectionSwitcher(
                context: context,
                ref: ref,
                assignments: assignments,
                activeAssignmentId: authorization?.activeAssignmentId,
                userGender: userGender,
              );
            }
          : null,
      child: Row(
        children: [
          // Club icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: clubColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedUserGroup,
                color: clubColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Club info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName ?? tr('dashboard.club_info.no_club'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (resolvedClubType != null)
                      SacBadge(label: resolvedClubType),
                    if (resolvedRole != null)
                      SacBadge(
                        label: resolvedRole,
                        variant: SacBadgeVariant.neutral,
                        icon: HugeIcons.strokeRoundedUser,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Trailing: up-down arrows when multiple assignments, plain chevron otherwise.
          if (hasMultiple)
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowUpDown,
              color: context.sac.textTertiary,
              size: 24,
            )
          else
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: context.sac.textTertiary,
              size: 24,
            ),
        ],
      ),
    );
  }
}
