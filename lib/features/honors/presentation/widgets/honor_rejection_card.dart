import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

/// Notice shown on top of both tabs when a reviewer rejected the honor: the
/// reason (or "Sin motivo especificado") and what to do next.
class HonorRejectionCard extends StatelessWidget {
  const HonorRejectionCard({super.key, this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;
    final trimmed = reason?.trim();

    return SacCard(
      key: const ValueKey('honor-rejection-card'),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusXS),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 20,
                  color: c.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'honors.requirements.rejected_title'.tr(),
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (trimmed != null && trimmed.isNotEmpty)
                        ? trimmed
                        : 'honors.evidence.rejection_no_reason'.tr(),
                    style: text.bodyMedium?.copyWith(
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'honors.requirements.rejected_hint'.tr(),
                    style: text.bodySmall?.copyWith(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
