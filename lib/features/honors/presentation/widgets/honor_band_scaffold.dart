import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haze/haze.dart';

import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_progress_band.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_segmented_tabs.dart';

/// Scroll distance over which the frosted top bar fades in.
const double kHonorTopBarFadeDistance = 48;

/// Scroll offset past which the honor name moves from the band to the bar.
const double kHonorTopBarTitleOffset = 72;

/// Scroll distance over which the bar turns from the band look (band-tinted
/// veil, white icons) into the page look (the app's white veil, dark icons),
/// ending when the band's bottom edge reaches the bar.
const double kHonorTopBarSurfaceDistance = 40;

/// Peak opacity of the band tint while the bar is over the band.
const double kHonorTopBarBandTintAlpha = 0.9;

/// Horizontal page padding of the band content, tabs and cards.
const double kHonorPagePadding = 20;

/// How far the tabs overlap the band's bottom edge.
const double kHonorTabsOverlap = 22;

/// Page frame shared by every honor screen: a transparent top bar with a
/// progressive frosted veil on scroll, the [HonorProgressBand], two floating
/// [HonorSegmentedTabs], the tab body and an optional sticky [bottomBar].
///
/// The veil is the app's usual one (no hard edge, it fades into the page).
/// Over the band it takes the band color and the icons stay white; once the
/// band scrolls away it eases into the white veil and dark icons every other
/// screen uses. The honor name moves into the bar once the band's name is
/// under it.
///
/// Pulling past the top shows the band color, not the page background.
///
/// It owns the scroll controller and the selected tab; the screen only says
/// what each tab shows through [tabBuilder].
class HonorBandScaffold extends StatefulWidget {
  const HonorBandScaffold({
    super.key,
    required this.bandColor,
    required this.paintColor,
    required this.honorName,
    required this.metaLabel,
    required this.step,
    required this.tabLabels,
    required this.tabBuilder,
    this.categoryName,
    this.imageUrl,
    this.progress,
    this.badge,
    this.actions = const [],
    this.bottomBar,
    this.initialTab = 0,
  });

  final Color bandColor;

  /// Category paint color (tab tint).
  final Color paintColor;
  final String honorName;
  final String? categoryName;
  final String? imageUrl;

  /// 0..1, or null for a band without ring.
  final double? progress;
  final Widget? badge;
  final String metaLabel;
  final HonorWorkStep? step;
  final List<String> tabLabels;
  final Widget Function(BuildContext context, int tab) tabBuilder;

  /// Top bar actions; they sit over the band, so icons must be white.
  final List<Widget> actions;
  final Widget? bottomBar;
  final int initialTab;

  @override
  State<HonorBandScaffold> createState() => _HonorBandScaffoldState();
}

class _HonorBandScaffoldState extends State<HonorBandScaffold> {
  final HonorBandBarController _bar =
      HonorBandBarController(titleOffset: kHonorTopBarTitleOffset);
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    _bar.scroll.addListener(() => _bar.update(SacTopBar.frostedInset(context)));
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    // On the tinted tab the band color holds contrast in light mode; in dark
    // mode the regular text color does.
    final onTint = isDark ? c.text : widget.bandColor;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: HonorBandTopBar(
        controller: _bar,
        title: widget.honorName,
        actions: widget.actions,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _bar.scroll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Paints the band color above the band, so an
                          // overscroll pull shows the band, not the page.
                          Positioned(
                            top: -screenHeight,
                            left: 0,
                            right: 0,
                            height: screenHeight,
                            child: ColoredBox(color: widget.bandColor),
                          ),
                          Column(
                            children: [
                              HonorProgressBand(
                                key: _bar.bandKey,
                                bandColor: widget.bandColor,
                                honorName: widget.honorName,
                                categoryName: widget.categoryName,
                                imageUrl: widget.imageUrl,
                                progress: widget.progress,
                                badge: widget.badge,
                                metaLabel: widget.metaLabel,
                                step: widget.step,
                                topInset: SacTopBar.frostedInset(context),
                              ),
                              const SizedBox(
                                height: HonorSegmentedTabs.height -
                                    kHonorTabsOverlap,
                              ),
                            ],
                          ),
                          Positioned(
                            left: kHonorPagePadding,
                            right: kHonorPagePadding,
                            bottom: 0,
                            child: HonorSegmentedTabs(
                              labels: widget.tabLabels,
                              selectedIndex: _tab,
                              accent: widget.paintColor,
                              selectedTextColor: onTint,
                              onChanged: (i) => setState(() => _tab = i),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          kHonorPagePadding,
                          16,
                          kHonorPagePadding,
                          24,
                        ),
                        child: SacStateSwap(
                          child: KeyedSubtree(
                            key: ValueKey('honor-tab-body-$_tab'),
                            child: widget.tabBuilder(context, _tab),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                HonorBandVeil(controller: _bar, bandColor: widget.bandColor),
              ],
            ),
          ),
          if (widget.bottomBar != null) widget.bottomBar!,
        ],
      ),
    );
  }
}

/// Scroll state behind the honor band's top bar, shared by every screen
/// that opens with a colored band ([HonorBandScaffold], the sub-items
/// screen).
///
/// Call [update] from a listener on [scroll] with the bar's inset; put
/// [bandKey] on the band so the bar knows where it ends.
class HonorBandBarController {
  HonorBandBarController({required this.titleOffset});

  /// Scroll offset past which [HonorBandTopBar] shows its title.
  final double titleOffset;

  final ScrollController scroll = ScrollController();
  final GlobalKey bandKey = GlobalKey();

  /// 0..1: how much of the frosted veil is showing.
  final ValueNotifier<double> frost = ValueNotifier<double>(0);

  /// 0..1: from the band look (0) to the page look (1).
  final ValueNotifier<double> surface = ValueNotifier<double>(0);

  /// Whether the bar shows its title.
  final ValueNotifier<bool> showTitle = ValueNotifier<bool>(false);

  void update(double inset) {
    if (!scroll.hasClients) return;
    final offset = scroll.offset;
    final f = (offset / kHonorTopBarFadeDistance).clamp(0.0, 1.0);
    if (f != frost.value) frost.value = f;

    // The band ends under the bar at `bandHeight - inset`; the look changes
    // over the distance just before that.
    final band = bandKey.currentContext?.findRenderObject() as RenderBox?;
    if (band != null && band.hasSize) {
      final end = band.size.height - inset;
      final s = ((offset - end + kHonorTopBarSurfaceDistance) /
              kHonorTopBarSurfaceDistance)
          .clamp(0.0, 1.0);
      if (s != surface.value) surface.value = s;
    }

    final t = offset > titleOffset;
    if (t != showTitle.value) showTitle.value = t;
  }

  void dispose() {
    scroll.dispose();
    frost.dispose();
    surface.dispose();
    showTitle.dispose();
  }
}

/// Transparent top bar over the band: white icons over the band, the
/// regular text color once the page scrolls under it, and [title] past the
/// controller's title offset. Publishes [HonorTopBarTone] for its actions.
class HonorBandTopBar extends StatelessWidget implements PreferredSizeWidget {
  const HonorBandTopBar({
    super.key,
    required this.controller,
    required this.title,
    this.actions = const [],
  });

  final HonorBandBarController controller;
  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(SacTopBar.compactHeight);

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    return AnimatedBuilder(
      animation: Listenable.merge([controller.showTitle, controller.surface]),
      builder: (context, _) {
        final surface = controller.surface.value;
        final onBand = surface < 0.5;
        final foreground = Color.lerp(Colors.white, c.text, surface)!;
        return HonorTopBarTone(
          foreground: foreground,
          onBand: onBand,
          child: SacTopBar(
            title: controller.showTitle.value ? title : '',
            frosted: true,
            foregroundColor: foreground,
            systemOverlayStyle: (onBand || isDark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: Colors.transparent),
            onBack: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).maybePop();
            },
            actions: actions,
          ),
        );
      },
    );
  }
}

/// The frosted veil behind [HonorBandTopBar], placed as a direct child of
/// the body [Stack] over the scroll view.
class HonorBandVeil extends StatelessWidget {
  const HonorBandVeil({
    super.key,
    required this.controller,
    required this.bandColor,
  });

  final HonorBandBarController controller;
  final Color bandColor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: SacTopBar.frostedInset(context) + SacFrostedVeil.fadeExtension,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge([controller.frost, controller.surface]),
          builder: (context, _) => _HonorFrostedVeil(
            bandColor: bandColor,
            amount: controller.frost.value,
            surface: controller.surface.value,
          ),
        ),
      ),
    );
  }
}

/// Progressive frosted veil behind the top bar, the same one as
/// [SacFrostedVeil]: strongest at the top, fading into the page with no edge.
///
/// [surface] blends its wash from the band color (over the band) to the app's
/// page wash (over the cards). [amount] (0..1) fades it in with the scroll; at
/// 0 nothing is painted.
class _HonorFrostedVeil extends StatelessWidget {
  const _HonorFrostedVeil({
    required this.bandColor,
    required this.amount,
    required this.surface,
  });

  final Color bandColor;
  final double amount;
  final double surface;

  static const double _sigma = 12;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();
    final dark = Theme.brightnessOf(context) == Brightness.dark;
    // Same wash as SacFrostedVeil.
    final pageWash = dark
        ? Colors.black.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.7);
    final bandWash = bandColor.withValues(alpha: kHonorTopBarBandTintAlpha);
    final wash = Color.lerp(bandWash, pageWash, surface)!;

    return Haze(
      key: const ValueKey('honor-frosted-bar'),
      edge: HazeEdge.top,
      sigma: _sigma * amount,
      tint: wash.withValues(alpha: wash.a * amount),
    );
  }
}

/// What the honor top bar looks like right now, for the actions it hosts:
/// over the band ([onBand]) icons are white on a translucent circle; over the
/// page they take the regular text color.
class HonorTopBarTone extends InheritedWidget {
  const HonorTopBarTone({
    super.key,
    required this.foreground,
    required this.onBand,
    required super.child,
  });

  final Color foreground;
  final bool onBand;

  static HonorTopBarTone? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HonorTopBarTone>();

  @override
  bool updateShouldNotify(HonorTopBarTone old) =>
      old.foreground != foreground || old.onBand != onBand;
}

/// Color of the text and icons that sit on the category tint (level chips,
/// info wells): the band color in light mode, the regular text in dark mode.
Color honorOnTint(BuildContext context, Color bandColor) =>
    Theme.brightnessOf(context) == Brightness.dark
        ? context.sac.text
        : bandColor;
