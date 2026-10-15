import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// Quiet "+ Agregar" chip on profile section headers and empty states.
/// Toma el acento elegido en Configuración. No es un CTA primario.
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
    final tone =
        SacAccent.of(context).forBrightness(Theme.of(context).brightness).color;

    return SacPressable(
      semanticLabel: semanticLabel ?? text,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tone.withValues(alpha: 0.16)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                color: tone,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
