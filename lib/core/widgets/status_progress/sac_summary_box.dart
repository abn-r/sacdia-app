import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Soft filled box that holds a summary. No border: the fill is the container.
class SacSummaryBox extends StatelessWidget {
  const SacSummaryBox({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: child,
    );
  }
}
