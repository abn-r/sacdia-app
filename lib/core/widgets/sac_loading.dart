import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// SACDIA loading indicator — animated stretched dots styled with
/// [AppColors.primary] on all platforms.
class SacLoading extends StatelessWidget {
  final Color? color;

  const SacLoading({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return LoadingAnimationWidget.stretchedDots(
      color: color ?? AppColors.primary,
      size: 50,
    );
  }
}

/// Compact SACDIA loading indicator — use inside buttons or small spaces.
class SacLoadingSmall extends StatelessWidget {
  final Color? color;

  const SacLoadingSmall({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return LoadingAnimationWidget.stretchedDots(
      color: color ?? AppColors.primary,
      size: 30,
    );
  }
}
