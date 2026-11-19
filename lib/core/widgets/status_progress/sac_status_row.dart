import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../animations/motion_tokens.dart';
import '../../theme/app_theme.dart';
import '../../theme/sac_colors.dart';
import '../sac_pressable.dart';
import 'sac_status_style.dart';

/// One item in a [SacGroupedSection]: status icon, title and the one line
/// that matters in its state. The end defaults to a chevron; pass [trailing]
/// to replace it (a button, a value).
class SacStatusRow extends StatelessWidget {
  const SacStatusRow({
    super.key,
    required this.style,
    required this.title,
    required this.detail,
    required this.onTap,
    this.detailIsError = false,
    this.trailing,
    this.statusKey,
  });

  final SacStatusStyle style;
  final String title;
  final String detail;
  final VoidCallback onTap;

  /// Shows [detail] in the error color and lets it use two lines.
  final bool detailIsError;

  /// Replaces the chevron.
  final Widget? trailing;

  /// Key of the status icon circle.
  final Key? statusKey;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacInkWell(
      onTap: onTap,
      pressedScale: SacMotion.rowPressScale,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Semantics(
                label: style.label,
                child: Container(
                  key: statusKey,
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: style.container,
                    shape: BoxShape.circle,
                  ),
                  child: ExcludeSemantics(
                    child: HugeIcon(
                      icon: style.icon,
                      size: 17,
                      color: style.onContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: detailIsError ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        height: 1.35,
                        color: detailIsError
                            ? c.onErrorContainer
                            : c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
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
