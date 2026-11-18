import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../theme/app_theme.dart';
import '../../theme/sac_colors.dart';
import '../sac_pressable.dart';
import 'sac_status_style.dart';

/// Where an item stands right now, in a card (like [SacCard]) with an icon tile tinted by [style]: the
/// current state, one line of context and a small "Step N of M". It does not
/// draw the whole path; tapping it opens the list of every state (see
/// [showSacStatesSheet]). A chevron says it is tappable.
///
/// Unlike [SacStatusPanel] it never shows a progress path: the owner wants
/// one state at a time and the rest one tap away.
class SacStatePanel extends StatelessWidget {
  const SacStatePanel({
    super.key,
    required this.style,
    required this.title,
    required this.onTap,
    this.message,
    this.stepLabel,
    this.semanticsHint,
  });

  final SacStatusStyle style;

  /// Already translated name of the current state.
  final String title;

  /// One line of context under the title.
  final String? message;

  /// "Step 2 of 4", already translated.
  final String? stepLabel;

  /// Screen reader hint for the tap ("Shows every state").
  final String? semanticsHint;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final message = this.message;
    final stepLabel = this.stepLabel;

    return Semantics(
      container: true,
      button: true,
      hint: semanticsHint,
      label: [
        title,
        if (message != null) message,
        if (stepLabel != null) stepLabel
      ].join('. '),
      excludeSemantics: true,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: c.surface,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: SacInkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: style.container,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    alignment: Alignment.center,
                    child: HugeIcon(
                      icon: style.icon,
                      size: 22,
                      color: style.onContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: SacFontSize.titleLarge,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: c.text,
                          ),
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: SacFontSize.bodyMedium,
                              height: 1.4,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                        if (stepLabel != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            stepLabel,
                            style: TextStyle(
                              fontSize: SacFontSize.bodySmall,
                              fontWeight: FontWeight.w600,
                              color: style.onContainer,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                    color: c.textTertiary,
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
