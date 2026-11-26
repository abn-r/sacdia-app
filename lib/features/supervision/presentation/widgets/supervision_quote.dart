import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_tone.dart';

/// Someone's words quoted in a white card: the reason of a rejection, the
/// requester's reason, the note of the local field. A small eyebrow
/// (icon + [label], tinted by [tone]) and the text under it.
///
/// Pass already translated text. The card reads as one node for a screen
/// reader: "label. text".
class SupervisionQuote extends StatelessWidget {
  const SupervisionQuote({
    super.key,
    required this.label,
    required this.text,
    this.icon = HugeIcons.strokeRoundedAlertCircle,
    this.tone = SacTone.muted,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 0),
  });

  final String label;
  final String text;
  final HugeIconData icon;
  final SacTone tone;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final palette = SacTonePalette.of(context, tone);
    return Padding(
      padding: padding,
      child: Semantics(
        container: true,
        label: '$label. $text',
        excludeSemantics: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HugeIcon(icon: icon, size: 15, color: palette.onContainer),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        fontWeight: FontWeight.w600,
                        color: palette.onContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: SacFontSize.titleSmall,
                  height: 1.45,
                  color: c.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
