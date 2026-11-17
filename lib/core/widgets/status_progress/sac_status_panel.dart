import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../theme/app_theme.dart';
import '../../theme/sac_colors.dart';
import 'sac_status_style.dart';
import 'sac_step_path.dart';

/// Where an item stands, in a soft box tinted by [style]: the state, one line
/// of context and a [SacStepPath]. An optional [note] sits below the box.
/// A pending style uses neutral ink instead of the tinted one.
class SacStatusPanel extends StatelessWidget {
  const SacStatusPanel({
    super.key,
    required this.style,
    required this.steps,
    required this.currentStep,
    required this.fill,
    required this.stepsSemanticsLabel,
    this.title,
    this.trailing,
    this.emphasizeTrailing = false,
    this.meta,
    this.note,
    this.stepPathKey,
  });

  final SacStatusStyle style;

  /// Defaults to `style.label`.
  final String? title;

  /// Value at the end of the title line (points, count).
  final String? trailing;

  /// Shows [trailing] big and in the ink color (a result) instead of small
  /// and secondary (a counter).
  final bool emphasizeTrailing;

  /// One line of context under the title.
  final String? meta;

  /// Already translated step names.
  final List<String> steps;
  final int currentStep;
  final double fill;
  final String stepsSemanticsLabel;

  /// Shown under the box, outside it, with a gap.
  final Widget? note;

  final Key? stepPathKey;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isPending = style.kind == SacStatusKind.pending;
    final ink = isPending ? c.text : style.onContainer;
    final meta = this.meta;
    final trailing = this.trailing;
    final note = this.note;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: style.container,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HugeIcon(icon: style.icon, size: 20, color: ink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title ?? style.label,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Text(
                      trailing,
                      style: TextStyle(
                        fontSize: emphasizeTrailing
                            ? SacFontSize.headlineSmall
                            : SacFontSize.bodySmall,
                        fontWeight: emphasizeTrailing
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: emphasizeTrailing ? ink : c.textSecondary,
                      ),
                    ),
                ],
              ),
              if (meta != null) ...[
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    height: 1.35,
                    color: isPending ? c.textSecondary : ink,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SacStepPath(
                key: stepPathKey,
                steps: steps,
                current: currentStep,
                fill: fill,
                color: ink,
                track: isPending ? c.border : ink.withValues(alpha: 0.22),
                labelColor: isPending ? c.textSecondary : ink,
                semanticsLabel: stepsSemanticsLabel,
              ),
            ],
          ),
        ),
        if (note != null) ...[const SizedBox(height: 12), note],
      ],
    );
  }
}
