import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/honor.dart';

/// Card de honor en catálogo - Estilo "Scout Vibrante"
///
/// SacCard con imagen/icono, nombre, nivel badge, chevron.
class HonorCard extends StatelessWidget {
  final Honor honor;
  final VoidCallback onTap;

  const HonorCard({
    super.key,
    required this.honor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SacCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Honor icon/image
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: honor.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      honor.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => HugeIcon(
                        icon: HugeIcons.strokeRoundedAward01,
                        color: AppColors.accent,
                        size: 24,
                      ),
                    ),
                  )
                : HugeIcon(
                    icon: HugeIcons.strokeRoundedAward01,
                    color: AppColors.accent,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  honor.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (honor.skillLevel != null) ...[
                  const SizedBox(height: 4),
                  SacBadge.warning(
                    label: 'Nivel ${honor.skillLevel}',
                    icon: HugeIcons.strokeRoundedStar,
                  ),
                ],
              ],
            ),
          ),

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
