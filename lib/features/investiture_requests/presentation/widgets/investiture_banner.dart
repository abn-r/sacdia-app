import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';

/// Tono del aviso: celebra, informa o frena.
enum InvestitureBannerTone { positive, neutral, caution }

/// Aviso de una línea o dos, con ícono en círculo. Misma anatomía que la
/// tarjeta de estado de investidura del detalle de clase.
class InvestitureBanner extends StatelessWidget {
  const InvestitureBanner({
    super.key,
    required this.text,
    this.tone = InvestitureBannerTone.neutral,
    this.icon,
  });

  final String text;
  final InvestitureBannerTone tone;
  final List<List<dynamic>>? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dark = Theme.brightnessOf(context) == Brightness.dark;
    final (
      Color accent,
      Color foreground,
      Color lightBg,
      List<List<dynamic>> glyph
    ) = switch (tone) {
      InvestitureBannerTone.positive => (
          AppColors.validatedColor,
          AppColors.validatedDark,
          AppColors.validatedBg,
          HugeIcons.strokeRoundedCalendar03,
        ),
      InvestitureBannerTone.neutral => (
          AppColors.sentColor,
          AppColors.sentDark,
          AppColors.sentBg,
          HugeIcons.strokeRoundedInformationCircle,
        ),
      InvestitureBannerTone.caution => (
          AppColors.coral700,
          AppColors.coral700,
          AppColors.coral50,
          HugeIcons.strokeRoundedAlert02,
        ),
    };
    final background = dark ? accent.withValues(alpha: 0.16) : lightBg;
    final textColor = dark ? c.ink900 : c.ink800;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.paper.withValues(alpha: dark ? 0.12 : 0.78),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: icon ?? glyph,
                size: 18,
                color: dark ? accent : foreground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
