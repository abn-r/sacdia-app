import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Pill-shaped segmented control that floats over the edge of the header
/// band. The selected segment is tinted with [accent] and its label uses
/// [selectedTextColor] (the band color, which holds contrast on the tint).
class HonorSegmentedTabs extends StatelessWidget {
  const HonorSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    required this.accent,
    required this.selectedTextColor,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color accent;
  final Color selectedTextColor;

  /// Visible segment height.
  static const double segmentHeight = 38;

  /// Pill height: segment plus its 4dp frame; also the tap target.
  static const double height = 46;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final duration = reduce ? Duration.zero : SacMotion.press;
    final text = Theme.of(context).textTheme;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.borderLight),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: c.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                label: labels[i],
                excludeSemantics: true,
                onTap: () => onChanged(i),
                child: GestureDetector(
                  key: ValueKey('honor-tab-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (i == selectedIndex) return;
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: Center(
                    child: AnimatedContainer(
                      duration: duration,
                      curve: SacMotion.easeOut,
                      height: segmentHeight,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: i == selectedIndex
                            ? accent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          fontWeight: i == selectedIndex
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: i == selectedIndex
                              ? selectedTextColor
                              : c.textSecondary,
                        ),
                      ),
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
