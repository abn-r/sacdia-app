import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Placeholder block for layout-matching skeletons of the coordinator views.
///
/// Static on purpose (no shimmer): skeletons only reserve the real layout so
/// content does not jump when it arrives.
class CoordinatorBone extends StatelessWidget {
  const CoordinatorBone({
    super.key,
    this.width,
    this.height,
    this.circle = false,
    this.radius = AppTheme.radiusXS / 2,
  });

  final double? width;

  /// Null fills the available height (e.g. inside an `AspectRatio`).
  final double? height;
  final bool circle;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.sac.border,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}
