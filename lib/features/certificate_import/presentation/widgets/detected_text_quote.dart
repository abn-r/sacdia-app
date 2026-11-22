import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// What the OCR read, shown as a quote ("lo que dice el papel") and not as a
/// field to fill: «Astronomía» · 14/11/2021 · Ver pág. 1. Read-only: the
/// member chooses from the catalog below.
///
/// Both actions are optional: [onViewProof] opens the proof at this row and
/// [onFix] lets the member correct a misread text.
class DetectedTextQuote extends StatelessWidget {
  const DetectedTextQuote({
    super.key,
    required this.text,
    this.date,
    this.onViewProof,
    this.proofLabel,
    this.onFix,
  });

  final String text;

  /// The date the OCR read, if any.
  final DateTime? date;
  final VoidCallback? onViewProof;

  /// Label for the proof action ("Ver pág. 2").
  final String? proofLabel;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final theme = Theme.of(context).textTheme;
    final read = [
      '«$text»',
      if (date != null) DateFormat('dd/MM/yyyy').format(date!),
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
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
                icon: HugeIcons.strokeRoundedFile01,
                size: 14,
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
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(read, style: theme.bodyLarge?.copyWith(color: c.text)),
              if (onViewProof != null)
                SacInkWell(
                  onTap: onViewProof,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          '· ${proofLabel ?? 'certificate_import.item.view_proof'.tr()}',
                          style: theme.bodyMedium?.copyWith(
                            color: accent.dark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (onFix != null)
            SacInkWell(
              onTap: onFix,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Text(
                    'certificate_import.editor.fix_text'.tr(),
                    style: theme.bodyMedium?.copyWith(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
