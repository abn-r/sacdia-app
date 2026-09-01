import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// Quiet mint "+ Agregar" chip used on profile section headers and empty
/// states. Matches the Especialidades header control — not a primary CTA.
class ProfileQuietAddChip extends StatelessWidget {
  final VoidCallback onTap;
  final String? semanticLabel;
  final String? label;

  const ProfileQuietAddChip({
    super.key,
    required this.onTap,
    this.semanticLabel,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final text = label ?? 'common.add'.tr();

    return SacPressable(
      semanticLabel: semanticLabel ?? text,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.secondary.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.secondary.withAlpha(40)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                color: AppColors.secondary,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
