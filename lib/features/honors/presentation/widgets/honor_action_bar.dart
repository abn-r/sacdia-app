import 'package:flutter/material.dart';

import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Sticky bottom bar of the honor screens: a surface with a soft top shadow
/// that holds the screen's primary action. It adds the bottom safe area.
class HonorActionBar extends StatelessWidget {
  const HonorActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
      decoration: BoxDecoration(
        color: c.surface,
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: child,
    );
  }
}
