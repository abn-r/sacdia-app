import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/sac_pressable.dart';

/// Label and value in a grouped card. [onTap] adds a chevron (the value can
/// be edited); [error] sits under the row's text, next to the field it is
/// about.
class MaterialsKvRow extends StatelessWidget {
  const MaterialsKvRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
    this.mono = false,
    this.onTap,
    this.error,
  });

  final String label;
  final String value;
  final bool emphasis;

  /// Identifiers (folios) use a monospace face and are never cut.
  final bool mono;
  final VoidCallback? onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final error = this.error;
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: emphasis
                          ? SacFontSize.titleMedium
                          : SacFontSize.titleSmall,
                      fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
                      color: emphasis ? c.text : c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: SacFontSize.titleMedium,
                            fontWeight:
                                emphasis ? FontWeight.w700 : FontWeight.w500,
                            color: emphasis ? c.text : c.textSecondary,
                            fontFamily: mono ? 'monospace' : null,
                            fontFeatures: SacMoney.tabularFigures,
                          ),
                        ),
                      ),
                      if (onTap != null) ...[
                        const SizedBox(width: 8),
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
                ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  error,
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    color: c.onErrorContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      label: '$label, $value${error == null ? '' : ', $error'}',
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: onTap == null ? body : SacInkWell(onTap: onTap, child: body),
    );
  }
}

/// One of a few mutually exclusive options as a card with a radio: title,
/// what it costs or means, and a selected border. Whole card is the target.
class RadioOptionCard extends StatelessWidget {
  const RadioOptionCard({
    super.key,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      excludeSemantics: true,
      label: '$title. $detail',
      onTap: onTap,
      child: Material(
        color: selected ? accent.surface : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          side: BorderSide(
            color: selected ? accent.color : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SacInkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? accent.color : c.textTertiary,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: accent.color,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: SacFontSize.titleMedium,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: TextStyle(
                            fontSize: SacFontSize.bodySmall,
                            height: 1.35,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
