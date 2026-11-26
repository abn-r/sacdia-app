import 'package:flutter/material.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';

/// One option of a [SupervisionSegmentedControl].
class SupervisionSegment<T> {
  const SupervisionSegment({
    required this.value,
    required this.label,
    this.count,
  });

  final T value;

  /// Already translated («Por validar»).
  final String label;

  /// Shown after the label in a lighter weight; omitted when null.
  final int? count;
}

/// Segmented control with counts: «Por validar 3 | Aprobadas 18 | Rechazadas
/// 1». A grey track holds the options and the selected one is a raised
/// surface pill; the count keeps a muted weight so the label leads.
///
/// For 2 to 4 mutually exclusive views of the same list. Every option is at
/// least 44 tall and shares the width; labels wrap instead of clipping when
/// the text is scaled up.
class SupervisionSegmentedControl<T> extends StatelessWidget {
  const SupervisionSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 0),
  });

  final List<SupervisionSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final segment in segments)
                Expanded(
                  child: _SegmentButton<T>(
                    segment: segment,
                    isSelected: segment.value == selected,
                    onTap: () => onChanged(segment.value),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({
    required this.segment,
    required this.isSelected,
    required this.onTap,
  });

  final SupervisionSegment<T> segment;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final count = segment.count;
    final duration = SacMotion.reduceMotionOf(context)
        ? SacMotion.reducedFade
        : SacMotion.standard;
    return Semantics(
      button: true,
      selected: isSelected,
      label: count == null ? segment.label : '${segment.label}, $count',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: c.shadow,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: segment.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? c.text : c.textSecondary,
                  ),
                ),
                if (count != null)
                  TextSpan(
                    text: ' $count',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: c.textTertiary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: SacFontSize.bodyMedium,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
