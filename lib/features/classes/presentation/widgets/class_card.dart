import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/class_logo_box.dart';

import '../../domain/entities/progressive_class.dart';

/// «Clase actual» card of Mis Clases: logo, name, «Cursando · year» and one
/// thin accent progress bar with the big percentage. No ring, no requirement
/// counts and no colored border: it uses the standard card surface.
class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.progressiveClass,
    required this.onTap,
    this.progress = 0.0,
  });

  final ProgressiveClass progressiveClass;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    final clamped = progress.clamp(0.0, 1.0);
    final percent = (clamped * 100).round();
    final year = _lastYear(progressiveClass.ecclesiasticalYearLabel);
    final status = year == null
        ? 'classes.catalog.status.in_progress'.tr()
        : 'classes.catalog.status.in_progress_year'.tr(
            namedArgs: {'year': year},
          );

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      label: 'classes.list.current_a11y'.tr(namedArgs: {
        'name': progressiveClass.name,
        'status': status,
        'percent': '$percent',
      }),
      child: SacCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClassLogoBox(
                  className: progressiveClass.name,
                  imageUrl: progressiveClass.imageUrl,
                  size: 52,
                  padding: 6,
                  radius: AppTheme.radiusSM,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progressiveClass.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.titleLarge,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SacProgressBar(
                    progress: clamped,
                    color: accent,
                    height: 6,
                    showShimmer: false,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: SacFontSize.displaySmall,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: c.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «2025–2026» → «2026»: a class is invested at the end of its year.
String? _lastYear(String? label) {
  if (label == null) return null;
  final years = RegExp(r'\d{4}').allMatches(label).toList();
  return years.isEmpty ? null : years.last.group(0);
}
