import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/sac_colors.dart';

/// Eyebrow label and one bordered card with the rows of a group, separated
/// by dividers indented past the status icon (58).
class SacGroupedSection extends StatelessWidget {
  const SacGroupedSection({
    super.key,
    required this.label,
    required this.children,
    this.count,
    this.action,
  });

  /// Already translated; shown uppercase.
  final String label;
  final List<Widget> children;

  /// Number shown at the end of the eyebrow; defaults to `children.length`.
  final int? count;

  /// Replaces the count at the end of the eyebrow (a text link such as
  /// "Select all"). Give it a 44dp tap target.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: SacFontSize.labelSmall,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: c.textTertiary,
                    ),
                  ),
                ),
                action ??
                    Text(
                      '${count ?? children.length}',
                      style: TextStyle(
                        fontSize: SacFontSize.labelSmall,
                        fontWeight: FontWeight.w600,
                        color: c.textTertiary,
                      ),
                    ),
              ],
            ),
          ),
          Material(
            color: c.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              side: BorderSide(color: c.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 58,
                      color: c.divider,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
