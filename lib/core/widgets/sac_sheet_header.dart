import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Canonical sheet drag handle: 36×4, tertiary @ 0.3, full radius.
class SacSheetGrabber extends StatelessWidget {
  const SacSheetGrabber({super.key, this.padded = true});

  /// When false, only the pill — parent owns vertical spacing.
  final bool padded;

  static const double pillWidth = 36;
  static const double pillHeight = 4;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      width: pillWidth,
      height: pillHeight,
      decoration: BoxDecoration(
        color: context.sac.textTertiary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
    );

    if (!padded) return Center(child: pill);

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(child: pill),
    );
  }
}

/// Canonical sheet chrome: grabber + title 17/w700 + optional close/actions.
class SacSheetHeader extends StatelessWidget {
  const SacSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.showGrabber = true,
    this.showClose = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final bool showGrabber;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final close = showClose
        ? IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              size: 22,
              color: c.textTertiary,
            ),
          )
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showGrabber) const SacSheetGrabber(),
        Padding(
          padding: EdgeInsets.fromLTRB(20, showGrabber ? 8 : 12, 12, 16),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: c.text,
                          ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 13,
                              color: c.textSecondary,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
              if (close != null) close,
            ],
          ),
        ),
      ],
    );
  }
}
