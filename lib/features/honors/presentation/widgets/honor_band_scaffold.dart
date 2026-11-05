import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_progress_band.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_segmented_tabs.dart';

/// Scroll distance after which the top bar takes the band color, so its white
/// icons stay readable over the cards.
const double kHonorTopBarSolidOffset = 96;

/// Horizontal page padding of the band content, tabs and cards.
const double kHonorPagePadding = 20;

/// How far the tabs overlap the band's bottom edge.
const double kHonorTabsOverlap = 22;

/// Page frame shared by every honor screen: a transparent top bar that turns
/// into the band color on scroll, the [HonorProgressBand], two floating
/// [HonorSegmentedTabs], the tab body and an optional sticky [bottomBar].
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
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _scrolled = ValueNotifier<bool>(false);
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final solid =
          _scroll.hasClients && _scroll.offset > kHonorTopBarSolidOffset;
      if (solid != _scrolled.value) _scrolled.value = solid;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _scrolled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    // On the tinted tab the band color holds contrast in light mode; in dark
    // mode the regular text color does.
    final onTint = isDark ? c.text : widget.bandColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(SacTopBar.compactHeight),
        child: ValueListenableBuilder<bool>(
          valueListenable: _scrolled,
          builder: (context, solid, _) => SacTopBar(
            title: '',
            foregroundColor: Colors.white,
            backgroundColor: solid ? widget.bandColor : Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            ),
            onBack: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).maybePop();
            },
            actions: widget.actions,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        children: [
                          HonorProgressBand(
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
                            height:
                                HonorSegmentedTabs.height - kHonorTabsOverlap,
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
          ),
          if (widget.bottomBar != null) widget.bottomBar!,
        ],
      ),
    );
  }
}

/// Color of the text and icons that sit on the category tint (level chips,
/// info wells): the band color in light mode, the regular text in dark mode.
Color honorOnTint(BuildContext context, Color bandColor) =>
    Theme.brightnessOf(context) == Brightness.dark
        ? context.sac.text
        : bandColor;
