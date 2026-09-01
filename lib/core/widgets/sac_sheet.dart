import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';

/// Modal bottom sheet with [SacMotion] drawer motion.
///
/// Enter [SacMotion.modal] (240ms), exit [SacMotion.routeExit] (200ms),
/// both [SacMotion.drawer]. Reduced motion skips the slide.
Future<T?> showSacSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  Color? barrierColor,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  bool useRootNavigator = false,
  BoxConstraints? constraints,
  bool? showDragHandle,
  ShapeBorder? shape,
  Clip? clipBehavior,
  AnimationController? transitionAnimationController,
}) {
  final reduce = SacMotion.reduceMotionOf(context);
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    constraints: constraints,
    showDragHandle: showDragHandle,
    shape: shape,
    clipBehavior: clipBehavior,
    transitionAnimationController: transitionAnimationController,
    sheetAnimationStyle: reduce
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: SacMotion.modal,
            reverseDuration: SacMotion.routeExit,
            curve: SacMotion.drawer,
            reverseCurve: SacMotion.drawer,
          ),
  );
}
