import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// Canonical toast. Theme owns shape; this owns voice.
///
/// Default [behavior] is floating. Use [SnackBarBehavior.fixed] when the
/// toast must sit above a shell [NavigationBar] (monthly reports).
abstract final class SacSnackBar {
  static const Duration display = Duration(seconds: 4);

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Color? backgroundColor,
    Duration? duration,
    Widget? leading,
    SnackBarAction? action,
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    showMessenger(
      ScaffoldMessenger.of(context),
      message,
      isError: isError,
      backgroundColor: backgroundColor,
      duration: duration,
      leading: leading,
      action: action,
      behavior: behavior,
      reduceMotion: SacMotion.reduceMotionOf(context),
    );
  }

  /// Same toast after capturing [ScaffoldMessenger] across an async gap.
  static void showMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    bool isError = false,
    Color? backgroundColor,
    Duration? duration,
    Widget? leading,
    SnackBarAction? action,
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    bool? reduceMotion,
  }) {
    final reduce = reduceMotion ?? SacMotion.reduceMotionOf(messenger.context);
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
          behavior: behavior,
          dismissDirection: behavior == SnackBarBehavior.floating
              ? DismissDirection.down
              : DismissDirection.horizontal,
          showCloseIcon: reduce,
          action: action,
        ),
      );
  }

  static void hide(BuildContext context) {
    hideMessenger(ScaffoldMessenger.of(context));
  }

  static void hideMessenger(ScaffoldMessengerState messenger) {
    messenger.hideCurrentSnackBar();
  }
}
