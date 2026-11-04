import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Canonical toast. Theme owns shape; this owns voice.
///
/// [isSuccess] keeps the neutral theme background and adds a green check
/// icon; [isError] paints the bar red with white text.
///
/// Default [behavior] is floating. Use [SnackBarBehavior.fixed] when the
/// toast must sit above a shell [NavigationBar] (monthly reports).
abstract final class SacSnackBar {
  static const Duration display = Duration(seconds: 4);

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
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
      isSuccess: isSuccess,
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
    bool isSuccess = false,
    Color? backgroundColor,
    Duration? duration,
    Widget? leading,
    SnackBarAction? action,
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    bool? reduceMotion,
  }) {
    assert(!(isError && isSuccess), 'isError and isSuccess are exclusive');
    final reduce = reduceMotion ?? SacMotion.reduceMotionOf(messenger.context);
    final bg = backgroundColor ?? (isError ? AppColors.error : null);
    final isErrorTone = isError && backgroundColor == null;

    final icon = leading ??
        (isSuccess
            ? _successIcon(Theme.of(messenger.context).brightness)
            : null);
    // White on #DC2626 is 4.83:1; the dark theme's black text is only 4.35:1.
    final text = Text(
      message,
      style: isErrorTone ? const TextStyle(color: Colors.white) : null,
    );

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: icon == null
              ? text
              : Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: text),
                  ],
                ),
          backgroundColor: bg,
          duration: duration ?? display,
          behavior: behavior,
          dismissDirection: behavior == SnackBarBehavior.floating
              ? DismissDirection.down
              : DismissDirection.horizontal,
          showCloseIcon: reduce,
          closeIconColor: isErrorTone ? Colors.white : null,
          action: action,
          // Since Flutter 3.29 a SnackBar with an action persists by default
          // (`persist = action != null`) and never auto-dismisses. Ours are
          // transient confirmations: always respect [duration].
          persist: false,
        ),
      );
  }

  // Snackbar surface is dark ink in the light theme and #F2F2F2 in the dark
  // one, so the check flips between the bright and the deep green (8.2:1 and
  // 5.7:1 against the surface).
  static Widget _successIcon(Brightness themeBrightness) {
    final isLightTheme = themeBrightness == Brightness.light;
    return HugeIcon(
      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
      size: 20,
      color: isLightTheme
          ? const SacColors(Brightness.light).success
          : const SacColors(Brightness.light).onSuccessContainer,
    );
  }

  static void hide(BuildContext context) {
    hideMessenger(ScaffoldMessenger.of(context));
  }

  static void hideMessenger(ScaffoldMessengerState messenger) {
    messenger.hideCurrentSnackBar();
  }
}
