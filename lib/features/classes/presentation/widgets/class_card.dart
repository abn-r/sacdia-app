import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
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
/// progress bar lineal indigo→emerald y badge de estado.
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
    final classColor = AppColors.classColor(progressiveClass.name);
    final logoAsset = AppColors.classLogoAsset(progressiveClass.name);
    final isExpired = progressiveClass.isExpired;

    return SacCard(
      onTap: onTap,
      accentColor: classColor,
      borderColor: isExpired
          ? AppColors.error.withValues(alpha: 0.45)
          : isCurrent
              ? classColor
              : null,
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
                  color: classColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: progressiveClass.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: progressiveClass.imageUrl!,
                          memCacheWidth: 132, // 44 * 3 (max device pixel ratio)
                          memCacheHeight: 132, // 44 * 3
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => logoAsset != null
                              ? Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Image.asset(
                                    logoAsset,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedSchool,
                                    color: classColor,
                                    size: 24,
                                  ),
                                ),
                        ),
                      )
                    : logoAsset != null
                        ? Padding(
                            padding: const EdgeInsets.all(6),
                            child: Image.asset(
                              logoAsset,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedSchool,
                              color: classColor,
                              size: 24,
                            ),
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
                        if (isExpired)
                          SacBadge(
                            label: 'classes.class_card.expired_badge'.tr(),
                          )
                        else if (isCurrent)
                          SacBadge(
                            label: 'classes.class_card.current_badge'.tr(),
                          ),
                      ],
                    ),
                    if (isExpired) ...[
                      const SizedBox(height: 4),
                      Text(
                        'classes.class_card.expired_description'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.errorDark,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
                  color: classColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
