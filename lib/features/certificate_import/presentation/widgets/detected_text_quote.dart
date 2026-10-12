import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

/// What the OCR read, shown as a quote ("lo que dice el papel") and not as a
/// field to fill. Read-only: the member chooses from the catalog below.
///
/// Both actions are optional: [onViewProof] opens the proof at this row and
/// [onFix] lets the member correct a misread text.
class DetectedTextQuote extends StatelessWidget {
  const DetectedTextQuote({
    super.key,
    required this.text,
    this.onViewProof,
    this.proofLabel,
    this.onFix,
  });

  final String text;
  final VoidCallback? onViewProof;

  /// Label for the proof action ("Ver en tu comprobante · pág. 2").
  final String? proofLabel;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedQuoteUp,
                size: 16,
                color: c.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                'certificate_import.editor.read_in_proof'.tr(),
                style: theme.labelMedium?.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '«$text»',
            style: theme.bodyLarge?.copyWith(color: c.text),
          ),
          Wrap(
            children: [
              if (onViewProof != null)
                SacButton.ghost(
                  text: proofLabel ?? 'certificate_import.item.view_proof'.tr(),
                  onPressed: onViewProof,
                ),
              if (onFix != null)
                SacButton.ghost(
                  text: 'certificate_import.editor.fix_text'.tr(),
                  onPressed: onFix,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
