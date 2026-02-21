import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/honor_category.dart';

/// Card de categoría de honor - Estilo "Scout Vibrante"
///
/// SacCard cuadrado con icono centrado y nombre.
class HonorCategoryCard extends StatelessWidget {
  final HonorCategory category;
  final VoidCallback onTap;

  const HonorCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SacCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAward01,
              size: 28,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            category.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
