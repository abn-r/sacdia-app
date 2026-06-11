import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// SACDIA back button rendered with HugeIcons.
///
/// Flutter's default AppBar back affordance uses Material's internal
/// BackButtonIcon, so AppBars that rely on implicit leading icons bypass the
/// app icon system. Use [sacAutoBackButton] with
/// `automaticallyImplyLeading: false` to preserve back behavior while keeping
/// the visual language on HugeIcons.
class SacBackButton extends StatelessWidget {
  const SacBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.size = 22,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final resolvedColor = color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;

    return IconButton(
      tooltip: tooltip ?? MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      icon: HugeIcon(
        icon: direction == TextDirection.rtl
            ? HugeIcons.strokeRoundedArrowRight01
            : HugeIcons.strokeRoundedArrowLeft01,
        size: size,
        color: resolvedColor,
      ),
    );
  }
}

/// Returns a HugeIcons back button only when the current navigator can pop.
Widget? sacAutoBackButton(
  BuildContext context, {
  VoidCallback? onPressed,
  Color? color,
  double size = 22,
  String? tooltip,
}) {
  if (onPressed == null && !Navigator.of(context).canPop()) {
    return null;
  }

  return SacBackButton(
    onPressed: onPressed,
    color: color,
    size: size,
    tooltip: tooltip,
  );
}
