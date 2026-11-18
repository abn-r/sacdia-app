import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/sac_colors.dart';

/// Fixed, blurred footer with the one main action of a screen and an optional
/// note under it. Place it in a [Stack] over the scrolling content and leave
/// [height] of room at the end of the list.
class SacFrostedFooter extends StatelessWidget {
  const SacFrostedFooter({super.key, required this.child, this.note});

  /// Usually a [SacButton.primary].
  final Widget child;

  /// One line under the button, already translated.
  final String? note;

  /// Room to leave at the end of the list (button plus a one-line note).
  static const double height = 120;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final note = this.note;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: c.canvas.withValues(alpha: 0.88),
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  child,
                  if (note != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      note,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        height: 1.4,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
