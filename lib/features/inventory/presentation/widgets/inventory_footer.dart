import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/sac_colors.dart';

/// Fixed, frosted footer that holds the one primary action of a screen.
class InventoryFooter extends StatelessWidget {
  const InventoryFooter({super.key, required this.child});

  final Widget child;

  /// Room a scrolling list leaves at its end so the footer never covers a row.
  static const double height = 96;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
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
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
