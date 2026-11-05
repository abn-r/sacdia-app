import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

/// Row of an info card: icon well, title, optional subtitle and a chevron
/// when it is tappable.
class HonorInfoRow extends StatelessWidget {
  const HonorInfoRow({
    super.key,
    required this.icon,
    required this.well,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final HugeIconData icon;
  final Color well;
  final Color iconColor;
  final String title;
  final String? subtitle;

  /// Null makes the row read-only (no chevron, no tap).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: well,
                borderRadius: BorderRadius.circular(AppTheme.radiusXS),
              ),
              child: Center(
                child: HugeIcon(icon: icon, size: 20, color: iconColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              ExcludeSemantics(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: onTap == null
            ? content
            : InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
                child: content,
              ),
      ),
    );
  }
}

/// Pill with an honor level ("Básico", "General"…).
class HonorLevelChip extends StatelessWidget {
  const HonorLevelChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: foreground,
              height: 1,
            ),
      ),
    );
  }
}

/// Description clamped to four lines with a "Ver más" / "Ver menos" toggle
/// (shown only when the text overflows).
class HonorClampedDescription extends StatefulWidget {
  const HonorClampedDescription({super.key, required this.text});

  final String text;

  @override
  State<HonorClampedDescription> createState() => _ClampedDescriptionState();
}

class _ClampedDescriptionState extends State<HonorClampedDescription> {
  static const _maxLines = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: c.textSecondary,
          height: 1.5,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _expanded ? null : _maxLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.fade,
              style: style,
            ),
            if (overflows)
              Semantics(
                button: true,
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _expanded
                            ? 'honors.requirements.see_less'.tr()
                            : 'honors.requirements.see_more'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: c.textSecondary,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
