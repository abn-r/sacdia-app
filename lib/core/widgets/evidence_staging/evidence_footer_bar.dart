import 'package:flutter/material.dart';

import '../../theme/sac_colors.dart';

/// The fixed bar at the bottom of the evidence screens: a surface with a top
/// border and a soft shadow that holds the screen's primary action.
class EvidenceFooterBar extends StatelessWidget {
  final Widget child;

  const EvidenceFooterBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
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
