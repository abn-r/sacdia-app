import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_progress_bar.dart';
import '../utils/grouped_class_status.dart';

/// Row of a [SacGroupedSection] that ends in a progress percentage: a leading
/// widget, title, one line of detail, a thin progress bar and a chevron.
class GroupedProgressRow extends StatelessWidget {
  const GroupedProgressRow({
    super.key,
    required this.leading,
    required this.title,
    required this.detail,
    required this.progress,
    required this.onTap,
  });

  final Widget leading;
  final String title;

  /// One line under the title. Use [TextSpan]s to color a part of it.
  final InlineSpan detail;

  /// 0-100.
  final int progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final percent = progress.clamp(0, 100);
    final color = groupedProgressColor(context, percent);

    return SacInkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        height: 1.35,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SacProgressBar(
                      progress: percent / 100,
                      height: 4,
                      color: color,
                      trackColor: c.border,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 42),
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: SacFontSize.titleSmall,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round 32px neutral badge that holds an icon (class rows).
class GroupedIconDot extends StatelessWidget {
  const GroupedIconDot({super.key, required this.icon, this.isAlert = false});

  final List<List<dynamic>> icon;

  /// Error tint, e.g. a class with no counselor.
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isAlert ? c.errorContainer : c.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: ExcludeSemantics(
        child: HugeIcon(
          icon: icon,
          size: 17,
          color: isAlert ? c.onErrorContainer : c.textSecondary,
        ),
      ),
    );
  }
}
