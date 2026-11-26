import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_tone.dart';

/// One level of a [SupervisionBreadcrumb].
class SupervisionCrumb {
  const SupervisionCrumb({required this.label, this.onTap});

  /// Already translated or a territory name.
  final String label;

  /// Goes back to this level. Null marks the current level (plain text).
  final VoidCallback? onTap;
}

/// Path of the territory the screen is drilled into: ancestors are tappable
/// accent-tinted chips that go back to that level, the current level is plain
/// text. Levels are separated by a chevron and wrap onto a second line when
/// they do not fit. Give the last crumb no `onTap`.
class SupervisionBreadcrumb extends StatelessWidget {
  const SupervisionBreadcrumb({
    super.key,
    required this.crumbs,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 0),
  });

  final List<SupervisionCrumb> crumbs;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: padding,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < crumbs.length; i++) ...[
            if (i > 0)
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 16,
                    color: c.textTertiary,
                  ),
                ),
              ),
            _CrumbView(crumb: crumbs[i]),
          ],
        ],
      ),
    );
  }
}

class _CrumbView extends StatelessWidget {
  const _CrumbView({required this.crumb});

  final SupervisionCrumb crumb;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final onTap = crumb.onTap;
    final palette = SacTonePalette.of(context, SacTone.accent);
    final isCurrent = onTap == null;

    final text = Text(
      crumb.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: SacFontSize.bodyMedium,
        height: 1.2,
        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
        color: isCurrent ? c.text : palette.onContainer,
      ),
    );

    if (isCurrent) {
      return Semantics(
        selected: true,
        label: crumb.label,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: text,
        ),
      );
    }
    // The visual chip is compact; the hit area keeps 44 of height.
    return Semantics(
      button: true,
      label: crumb.label,
      excludeSemantics: true,
      onTap: onTap,
      child: SacInkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: palette.container,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: text,
            ),
          ),
        ),
      ),
    );
  }
}
