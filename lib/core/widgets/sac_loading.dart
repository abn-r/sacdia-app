import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// SACDIA loading indicator — [CircularProgressIndicator] styled with
/// [AppColors.primary] on all platforms (unified iOS-inspired experience).
class SacLoading extends StatelessWidget {
  final Color? color;
  final double? strokeWidth;

  const SacLoading({super.key, this.color, this.strokeWidth});

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      color: color ?? AppColors.sacBlack,
      strokeWidth: strokeWidth ?? 4.0,
    );
  }
}

/// Compact SACDIA loading indicator — use inside buttons or small spaces.
///
/// Uses [CircularProgressIndicator] with [strokeWidth] 2.0 on all platforms.
class SacLoadingSmall extends StatelessWidget {
  final Color? color;

  const SacLoadingSmall({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      color: color ?? AppColors.sacBlack,
      strokeWidth: 2.0,
    );
  }
}
