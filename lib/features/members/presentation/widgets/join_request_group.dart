import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import 'join_request_row.dart';

/// A titled group of request rows: dot + «title · count» header and the rows in
/// one rounded container, split by hairline dividers.
class JoinRequestGroupSection extends StatelessWidget {
  const JoinRequestGroupSection({
    super.key,
    required this.title,
    required this.count,
    required this.dotColor,
    required this.children,
    this.trailing,
  });

  final String title;
  final int count;
  final Color dotColor;
  final List<Widget> children;

  /// Optional action at the right end of the header.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Semantics(
            header: true,
            child: Row(
              children: [
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration:
                        BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    child: const SizedBox(width: 8, height: 8),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$title · $count',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
        SacCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: kJoinRequestRowTextInset,
                      color: c.borderLight,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
