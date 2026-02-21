import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

/// Card de información del club - Estilo "Scout Vibrante"
///
/// SacCard con barra de acento lateral del color del club,
/// badges para tipo y rol, icono de grupo.
class ClubInfoCard extends StatelessWidget {
  final String? clubName;
  final String? clubType;
  final String? userRole;

  const ClubInfoCard({
    super.key,
    this.clubName,
    this.clubType,
    this.userRole,
  });

  Color _getClubColor(String? type) {
    if (type == null) return AppColors.primary;
    switch (type.toLowerCase()) {
      case 'conquistadores':
        return AppColors.primary;
      case 'aventureros':
        return AppColors.error;
      case 'guías mayores':
      case 'guias mayores':
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clubColor = _getClubColor(clubType);

    return SacCard(
      accentColor: clubColor,
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
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedUserGroup,
              color: clubColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Club info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName ?? 'Sin club asignado',
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
                    if (clubType != null)
                      SacBadge(label: clubType!),
                    if (userRole != null)
                      SacBadge(
                        label: userRole!,
                        variant: SacBadgeVariant.neutral,
                        icon: HugeIcons.strokeRoundedUser,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Chevron
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            color: AppColors.lightTextTertiary,
            size: 24,
          ),
        ],
      ),
    );
  }
}
