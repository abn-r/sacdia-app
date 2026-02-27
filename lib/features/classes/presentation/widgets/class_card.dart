import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';

import '../../domain/entities/progressive_class.dart';

/// Card de clase progresiva - Estilo "Scout Vibrante"
///
/// SacCard con barra de acento lateral (color de clase),
/// progress bar lineal indigo→emerald, badge "Clase actual".
class ClassCard extends StatelessWidget {
  final ProgressiveClass progressiveClass;
  final double progress;
  final bool isCurrent;
  final VoidCallback onTap;

  const ClassCard({
    super.key,
    required this.progressiveClass,
    this.progress = 0.0,
    this.isCurrent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progressPercent = (progress * 100).toInt();

    return SacCard(
      onTap: onTap,
      accentColor: AppColors.primary,
      borderColor: isCurrent ? AppColors.primary : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Class icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: progressiveClass.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          progressiveClass.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => HugeIcon(
                            icon: HugeIcons.strokeRoundedSchool,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                      )
                    : HugeIcon(
                        icon: HugeIcons.strokeRoundedSchool,
                        color: AppColors.primary,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 14),

              // Class info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            progressiveClass.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent)
                          const SacBadge(label: 'Clase actual'),
                      ],
                    ),
                    if (progressiveClass.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        progressiveClass.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.sac.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          Row(
            children: [
              Expanded(
                child: SacProgressBar(progress: progress),
              ),
              const SizedBox(width: 12),
              Text(
                '$progressPercent%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
