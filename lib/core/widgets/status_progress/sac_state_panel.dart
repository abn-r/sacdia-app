import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../theme/app_theme.dart';
import '../sac_pressable.dart';
import 'sac_status_style.dart';

/// Where an item stands right now, in one soft box tinted by [style]: the
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
    final ink = style.onContainer;
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
      child: Material(
        color: style.container,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: SacInkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HugeIcon(icon: style.icon, size: 20, color: ink),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: SacFontSize.titleLarge,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 18,
                      color: ink.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                if (message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      height: 1.4,
                      color: ink,
                    ),
                  ),
                ],
                if (stepLabel != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    stepLabel,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      fontWeight: FontWeight.w600,
                      color: ink.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
