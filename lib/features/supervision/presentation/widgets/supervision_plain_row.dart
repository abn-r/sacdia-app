import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// Row of a grouped list without a leading icon: a name, what stands out
/// about it, and an optional value at the end.
///
/// Used where every row is the same kind of thing (territories, clubs), so an
/// icon per row would only repeat itself. Pair it with
/// `SacGroupedSection(dividerIndent: 16)`.
class SupervisionPlainRow extends StatelessWidget {
  const SupervisionPlainRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleSpans,
    this.trailing,
    this.footer,
    this.onTap,
  });

  final String title;
  final String? subtitle;

  /// Subtitle in parts, when one part needs its own color. Wins over
  /// [subtitle].
  final List<TextSpan>? subtitleSpans;

  /// Short value at the end of the row; it drops below the title when the
  /// text is scaled up.
  final Widget? trailing;

  /// Full-width content under the texts (a progress bar).
  final Widget? footer;

  /// Makes the row a button and shows the chevron.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final hasSpans = subtitleSpans != null && subtitleSpans!.isNotEmpty;
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;

    final texts = Column(
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
            color: c.text,
          ),
        ),
        if (hasSpans || hasSubtitle) ...[
          const SizedBox(height: 2),
          Text.rich(
            hasSpans
                ? TextSpan(children: subtitleSpans)
                : TextSpan(text: subtitle),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              height: 1.3,
              color: c.textSecondary,
            ),
          ),
        ],
        if (stacked && trailing != null) ...[
          const SizedBox(height: 6),
          trailing!,
        ],
      ],
    );

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, onTap == null ? 16 : 10, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(child: texts),
                if (!stacked && trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  ExcludeSemantics(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 18,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
            if (footer != null) ...[
              const SizedBox(height: 10),
              // Keeps the bar clear of the chevron column.
              Padding(
                padding: EdgeInsets.only(right: onTap == null ? 0 : 6),
                child: footer,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return MergeSemantics(child: row);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: SacInkWell(
          onTap: onTap,
          pressedScale: SacMotion.rowPressScale,
          child: row,
        ),
      ),
    );
  }
}

/// Figure at the end of a [SupervisionPlainRow]: tabular digits so a column
/// of rows lines up.
class SupervisionRowValue extends StatelessWidget {
  const SupervisionRowValue(this.value, {super.key, this.suffix});

  final String value;

  /// Quieter text after the figure ("de 15").
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Text.rich(
      TextSpan(
        text: value,
        children: [
          if (suffix != null && suffix!.isNotEmpty)
            TextSpan(
              text: ' $suffix',
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                fontWeight: FontWeight.w400,
                color: c.textSecondary,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: SacFontSize.titleLarge,
        fontWeight: FontWeight.w600,
        color: c.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
