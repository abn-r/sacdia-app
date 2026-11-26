import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_theme.dart';
import '../theme/sac_colors.dart';
import 'sac_list_row.dart';

/// "From → to": the place something leaves and the one it goes to, as two
/// rows joined by a thin strip with the [connector] text («CAMBIO A»).
///
/// Lives inside a `SacGroupedSection` (with `dividerIndent: 0`). The leading
/// widgets are the caller's (a club type tile, an avatar). When there is no
/// origin only the destination shows, without the strip.
class SacMoveBox extends StatelessWidget {
  const SacMoveBox({
    super.key,
    required this.connector,
    required this.toLeading,
    required this.toTitle,
    this.toSubtitle,
    this.fromLeading,
    this.fromTitle,
    this.fromSubtitle,
  });

  /// Already translated; shown uppercase on the strip.
  final String connector;

  final Widget toLeading;
  final String toTitle;
  final String? toSubtitle;

  final Widget? fromLeading;
  final String? fromTitle;
  final String? fromSubtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final fromTitle = this.fromTitle?.trim();
    final fromLeading = this.fromLeading;
    return Column(
      children: [
        if (fromTitle != null &&
            fromTitle.isNotEmpty &&
            fromLeading != null) ...[
          SacListRow(
            leading: fromLeading,
            title: fromTitle,
            subtitle: fromSubtitle,
          ),
          Container(
            height: 24,
            color: c.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    size: 14,
                    color: c.textTertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  connector.toUpperCase(),
                  style: TextStyle(
                    fontSize: SacFontSize.labelSmall,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
        SacListRow(
          leading: toLeading,
          title: toTitle,
          subtitle: toSubtitle,
        ),
      ],
    );
  }
}
