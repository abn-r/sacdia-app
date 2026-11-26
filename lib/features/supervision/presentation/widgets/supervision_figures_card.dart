import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_tone.dart';

/// One figure of a [SupervisionFiguresCard]: a big number, an optional
/// «de 21» next to it and what it counts.
class SupervisionFigure {
  const SupervisionFigure({
    required this.value,
    required this.label,
    this.suffix,
    this.tone,
    this.onTap,
  });

  /// Already formatted («1,240»).
  final String value;

  /// What it counts («Miembros activos»). Already translated.
  final String label;

  /// Small text after [value] («de 21»).
  final String? suffix;

  /// Colors the number when it needs attention (warning). Null: plain.
  final SacTone? tone;

  /// Makes the cell a button and shows a chevron after the label.
  final VoidCallback? onTap;
}

/// Card of up to four figures in two columns, split by hairlines.
///
/// Fills the row of an odd count with an empty cell. Wrap the card in the
/// screen's 20 inset (built in).
class SupervisionFiguresCard extends StatelessWidget {
  const SupervisionFiguresCard({
    super.key,
    required this.figures,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 0),
  });

  final List<SupervisionFigure> figures;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (figures.isEmpty) return const SizedBox.shrink();
    final c = context.sac;
    final rows = <Widget>[];
    for (var i = 0; i < figures.length; i += 2) {
      final second = i + 1 < figures.length ? figures[i + 1] : null;
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: c.divider));
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _FigureCell(figure: figures[i])),
              VerticalDivider(width: 1, thickness: 1, color: c.divider),
              Expanded(
                child: second == null
                    ? const SizedBox.shrink()
                    : _FigureCell(figure: second),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          side: BorderSide(color: c.border),
        ),
        child: Column(children: rows),
      ),
    );
  }
}

class _FigureCell extends StatelessWidget {
  const _FigureCell({required this.figure});

  final SupervisionFigure figure;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final tone = figure.tone;
    final valueColor =
        tone == null ? c.text : SacTonePalette.of(context, tone).onContainer;
    final onTap = figure.onTap;
    final suffix = figure.suffix;

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: figure.value,
                    style: TextStyle(
                      fontSize: SacFontSize.headlineSmall,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: valueColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (suffix != null)
                    TextSpan(
                      text: ' $suffix',
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        color: c.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Flexible(
                  child: Text(
                    figure.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      height: 1.25,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  ExcludeSemantics(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 14,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return MergeSemantics(child: content);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: SacInkWell(
          onTap: onTap,
          pressedScale: SacMotion.rowPressScale,
          child: content,
        ),
      ),
    );
  }
}
