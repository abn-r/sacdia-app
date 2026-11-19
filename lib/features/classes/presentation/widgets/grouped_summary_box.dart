import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/animations/animated_counter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../utils/grouped_class_status.dart';

/// Soft box that opens each screen of the grouped-class flow: a small label,
/// one big number, the status bar and, below a divider, whatever the screen
/// adds ([footer]: the scope banner, the counselor cards, a key/value line).
///
/// [leading] goes above the label (the scope banner).
class GroupedSummaryBox extends StatelessWidget {
  const GroupedSummaryBox({
    super.key,
    this.label,
    required this.value,
    required this.counts,
    this.countLabels,
    this.valueSuffix,
    this.leading,
    this.footer,
    this.footerDivider = true,
    this.valueCount,
    this.valueText,
  });

  /// Small text above [value]; the module screen leaves it out.
  final String? label;
  final String value;

  /// When both are set the number inside [value] counts up to [valueCount]
  /// and [valueText] renders the text for each step; [value] must equal
  /// `valueText(valueCount)` (it is what a screen reader hears).
  final int? valueCount;
  final String Function(int count)? valueText;

  /// Legend text of the bar; defaults to [groupedCountLabels].
  final SacStatusCountLabels? countLabels;

  /// Small text next to [value] ("· 9 members").
  final String? valueSuffix;
  final StatusCounts counts;
  final Widget? leading;
  final Widget? footer;

  /// Draws a divider between the bar and [footer].
  final bool footerDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final footer = this.footer;
    final leading = this.leading;
    return SacSummaryBox(
      color: c.surfaceVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading, const SizedBox(height: 14)],
          if (label != null) ...[
            Text(
              label!,
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
          ],
          _valueLine(context),
          if (counts.total > 0) ...[
            const SizedBox(height: 12),
            SacStatusBar.counts(
              counts: counts,
              countLabels: countLabels ?? groupedCountLabels(counts),
            ),
          ],
          if (footer != null) ...[
            if (footerDivider) ...[
              const SizedBox(height: 14),
              Divider(height: 1, thickness: 1, color: c.border),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 14),
            footer,
          ],
        ],
      ),
    );
  }

  Widget _richValue(BuildContext context, String text) {
    final c = context.sac;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: text,
            style: TextStyle(
              fontSize: SacFontSize.displayMedium,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: c.text,
            ),
          ),
          if (valueSuffix != null)
            TextSpan(
              text: '  $valueSuffix',
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                color: c.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _valueLine(BuildContext context) {
    final count = valueCount;
    final text = valueText;
    if (count == null || text == null) return _richValue(context, value);
    // Counts up on first build and on real changes; a screen reader hears
    // only the final value, never the steps.
    return Semantics(
      label: valueSuffix == null ? value : '$value  $valueSuffix',
      excludeSemantics: true,
      child: AnimatedCounter(
        value: count,
        builder: (context, n) => _richValue(context, text(n)),
      ),
    );
  }
}

/// "Label ........ value" line used under the bar of a summary box.
class GroupedKeyValueLine extends StatelessWidget {
  const GroupedKeyValueLine({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              color: c.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: SacFontSize.titleSmall,
            fontWeight: FontWeight.w600,
            color: valueColor ?? c.text,
          ),
        ),
      ],
    );
  }
}

/// Text with `**bold**` segments, so a translation can mark its own emphasis.
class GroupedBoldText extends StatelessWidget {
  const GroupedBoldText(this.text, {super.key, this.color, this.boldColor});

  final String text;
  final Color? color;
  final Color? boldColor;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final parts = text.split('**');
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd
                  ? TextStyle(
                      fontWeight: FontWeight.w700,
                      color: boldColor ?? c.text,
                    )
                  : null,
            ),
        ],
      ),
      style: TextStyle(
        fontSize: SacFontSize.bodySmall,
        height: 1.4,
        color: color ?? c.textSecondary,
      ),
    );
  }
}

/// "Average progress" label with the percentage and its suffix, shared by
/// the class and scope summaries.
String groupedPercentText(int percent) => '$percent%';

/// "· 9 members in 6 classes".
String groupedMembersInClasses(int members, int classes) =>
    'classes.grouped.members_in_classes'.tr(namedArgs: {
      'members': 'classes.grouped.members_count'.plural(members),
      'classes': 'classes.grouped.classes_count'.plural(classes),
    });
