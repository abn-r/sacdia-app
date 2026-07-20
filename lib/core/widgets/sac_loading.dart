import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

const double _loadingSize = 30;

/// SACDIA loading indicator — animated dots normally and a static three-dot
/// mark under Reduced Motion, styled with [AppColors.primary] by default.
class SacLoading extends StatelessWidget {
  final Color? color;

  const SacLoading({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return _loadingIndicator(context, color ?? AppColors.primary);
  }
}

/// Compact SACDIA loading indicator — use inside buttons or small spaces.
class SacLoadingSmall extends StatelessWidget {
  final Color? color;

  const SacLoadingSmall({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return _loadingIndicator(context, color ?? AppColors.primary);
  }
}

Widget _loadingIndicator(BuildContext context, Color color) {
  if (SacMotion.reduceMotionOf(context)) {
    return SizedBox.square(
      dimension: _loadingSize,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          3,
          (_) => Container(
            width: _loadingSize / 5,
            height: _loadingSize / 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  return LoadingAnimationWidget.waveDots(
    color: color,
    size: _loadingSize,
  );
}
