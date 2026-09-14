import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// Canonical floating toast. Theme owns shape/behavior; this owns voice.
abstract final class SacSnackBar {
  static const Duration display = Duration(seconds: 4);

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Color? backgroundColor,
    Duration? duration,
    Widget? leading,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final reduce = SacMotion.reduceMotionOf(context);
    final bg = backgroundColor ?? (isError ? AppColors.error : null);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: leading == null
              ? Text(message)
              : Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: Text(message)),
                  ],
                ),
          backgroundColor: bg,
          duration: duration ?? display,
          behavior: SnackBarBehavior.floating,
          dismissDirection: DismissDirection.down,
          showCloseIcon: reduce,
        ),
      );
  }

  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
}
