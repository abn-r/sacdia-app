import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_level_labels.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_info_parts.dart';

/// "Información" tab of an honor the member is not working yet (catalog and
/// "choose how to work it"): description, level chips, study material and the
/// three "Cómo funciona" steps.
class HonorCatalogInfoTab extends StatelessWidget {
  const HonorCatalogInfoTab({
    super.key,
    required this.honor,
    required this.paintColor,
    required this.chipForeground,
  });

  final Honor honor;
  final Color paintColor;

  /// Text color on the level chips (they sit on the paint at 12%).
  final Color chipForeground;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;
    final description = honor.description?.trim();
    final materialUrl = honor.materialUrl?.trim();
    final chipBackground = paintColor.withValues(alpha: 0.12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (description != null && description.isNotEmpty) ...[
          SacCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'honors.detail.description_label'.tr(),
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 8),
                HonorClampedDescription(text: description),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        SacCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (materialUrl != null && materialUrl.isNotEmpty) ...[
                HonorInfoRow(
                  key: const ValueKey('info-row-material'),
                  icon: HugeIcons.strokeRoundedPdf01,
                  well: chipBackground,
                  iconColor: chipForeground,
                  title: 'honors.evidence.material_title'.tr(),
                  subtitle: 'honors.evidence.material_subtitle'.tr(),
                  onTap: () => SacPdfViewer.show(
                    context,
                    pdfSource: materialUrl,
                    title: honor.name,
                  ),
                ),
                Divider(height: 1, thickness: 1, color: c.borderLight),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (honor.skillLevel != null)
                      HonorLevelChip(
                        label: honorSkillLevelLabel(honor.skillLevel),
                        background: chipBackground,
                        foreground: chipForeground,
                      ),
                    HonorLevelChip(
                      label: honorApprovalLabel(honor.approval),
                      background: chipBackground,
                      foreground: chipForeground,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HowItWorksCard(accent: chipForeground),
      ],
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;
    final steps = [
      (
        title: 'honors.detail.step1_title'.tr(),
        subtitle: 'honors.detail.step1_subtitle'.tr(),
      ),
      (
        title: 'honors.detail.step2_title'.tr(),
        subtitle: 'honors.detail.step2_subtitle'.tr(),
      ),
      (
        title: 'honors.detail.step3_title'.tr(),
        subtitle: 'honors.detail.step3_subtitle'.tr(),
      ),
    ];

    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'honors.detail.how_it_works'.tr(),
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'honors.detail.how_it_works_intro'.tr(),
            style: text.bodyMedium?.copyWith(
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            _HowItWorksStep(
              index: i + 1,
              title: steps[i].title,
              subtitle: steps[i].subtitle,
              accent: accent,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  const _HowItWorksStep({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.isLast,
  });

  final int index;
  final String title;
  final String subtitle;
  final Color accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                    ),
                    child: Text(
                      '$index',
                      style: text.bodyMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Align(
                        child: Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          color: c.border,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleSmall?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: text.bodyMedium?.copyWith(
                        color: c.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
