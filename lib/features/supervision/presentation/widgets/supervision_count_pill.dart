import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/widgets/sac_tone.dart';

/// Filled accent pill with a number («6»), the trailing mark of a queue row
/// that has something waiting. Tabular digits so it does not jitter when the
/// count changes; at least 24 wide so a single digit stays a circle.
///
/// Inside a merged row (`SacListRow`) wrap it in `ExcludeSemantics`: the
/// row's own second line already says the number.
class SupervisionCountPill extends StatelessWidget {
  const SupervisionCountPill(
      {super.key, required this.count, this.semanticLabel});

  final int count;

  /// Spoken label when the pill is read on its own (default: the number).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    return Semantics(
      label: semanticLabel ?? '$count',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.color,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Text(
          '$count',
          maxLines: 1,
          style: TextStyle(
            fontSize: SacFontSize.bodySmall,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: accent.onColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// «Al día»: check icon plus text in the success color. The state of a queue
/// with nothing waiting; the icon makes it readable without color.
class SupervisionAllClearLabel extends StatelessWidget {
  const SupervisionAllClearLabel({super.key, this.label});

  /// Defaults to `supervision.hub.up_to_date` («Al día»).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = SacTonePalette.of(context, SacTone.success).onContainer;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedTick02,
            size: 14,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label ?? 'supervision.hub.up_to_date'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
