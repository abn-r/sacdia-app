import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

class SacShellDestination {
  const SacShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final Widget icon;
  final Widget selectedIcon;
  final String label;
}

/// Phone shell bar. Same theme colors as [NavigationBar], press scale per tab.
class SacShellNavBar extends StatelessWidget {
  const SacShellNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<SacShellDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = NavigationBarTheme.of(context);
    final background =
        theme.backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer;
    final height = theme.height ?? 80;
    final indicatorColor = theme.indicatorColor ??
        Theme.of(context).colorScheme.secondaryContainer;
    final indicatorShape = theme.indicatorShape ?? const StadiumBorder();

    return Material(
      color: background,
      elevation: theme.elevation ?? 0,
      shadowColor: theme.shadowColor ?? Colors.transparent,
      surfaceTintColor: theme.surfaceTintColor ?? Colors.transparent,
      child: SafeArea(
        child: Semantics(
          explicitChildNodes: true,
          container: true,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _ShellDestinationButton(
                      selected: i == selectedIndex,
                      destination: destinations[i],
                      indicatorColor: indicatorColor,
                      indicatorShape: indicatorShape,
                      indicatorWidth: 64,
                      iconTheme: theme.iconTheme?.resolve(
                        i == selectedIndex
                            ? const {WidgetState.selected}
                            : const <WidgetState>{},
                      ),
                      labelStyle: theme.labelTextStyle?.resolve(
                        i == selectedIndex
                            ? const {WidgetState.selected}
                            : const <WidgetState>{},
                      ),
                      onPressed: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wide shell rail. Same colors the previous [NavigationRail] resolved.
class SacShellNavRail extends StatelessWidget {
  const SacShellNavRail({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<SacShellDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rail = NavigationRailTheme.of(context);
    final background = rail.backgroundColor ?? colors.surface;
    final width = rail.minWidth ?? 80;
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: colors.onSurface,
    );
    final indicatorColor = rail.indicatorColor ?? colors.secondaryContainer;
    final indicatorShape = rail.indicatorShape ?? const StadiumBorder();
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Semantics(
      explicitChildNodes: true,
      child: Material(
        elevation: rail.elevation ?? 0,
        color: background,
        child: SafeArea(
          right: rtl,
          left: !rtl,
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: _ShellDestinationButton(
                              selected: i == selectedIndex,
                              destination: destinations[i],
                              indicatorColor: indicatorColor,
                              indicatorShape: indicatorShape,
                              indicatorWidth: 56,
                              labelStyle: labelStyle,
                              onPressed: () => onSelected(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellDestinationButton extends StatelessWidget {
  const _ShellDestinationButton({
    required this.selected,
    required this.destination,
    required this.indicatorColor,
    required this.indicatorShape,
    required this.indicatorWidth,
    required this.onPressed,
    this.iconTheme,
    this.labelStyle,
  });

  final bool selected;
  final SacShellDestination destination;
  final Color indicatorColor;
  final ShapeBorder indicatorShape;
  final double indicatorWidth;
  final VoidCallback onPressed;
  final IconThemeData? iconTheme;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    final icon = IconTheme.merge(
      data: iconTheme ?? const IconThemeData(size: 24),
      child: selected ? destination.selectedIcon : destination.icon,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: SacPressable(
        onTap: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: indicatorWidth,
              height: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: reduce ? Duration.zero : SacMotion.standard,
                    curve: SacMotion.easeOut,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: indicatorColor,
                        shape: indicatorShape,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  icon,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: labelStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
