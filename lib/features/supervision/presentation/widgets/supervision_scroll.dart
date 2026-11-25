import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

/// Widest a supervision column grows on a tablet.
const double kSupervisionMaxContentWidth = 640;

/// Refreshable body of a supervision screen that sits under a frosted
/// [SacTopBar]: one centered column, or one state centered in the viewport.
class SupervisionScroll extends StatelessWidget {
  const SupervisionScroll({
    super.key,
    required this.onRefresh,
    required this.child,
    this.fill = false,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// Centers [child] in the viewport (loading, empty and error states).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final bounded = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: kSupervisionMaxContentWidth,
        ),
        child: child,
      ),
    );
    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (fill)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(
                  top: SacTopBar.frostedInset(context),
                ),
                child: bounded,
              ),
            )
          else
            SliverPadding(
              padding: SacTopBar.paddingBelowBar(
                context,
                const EdgeInsets.only(bottom: 32),
              ),
              sliver: SliverToBoxAdapter(
                child: Align(alignment: Alignment.topCenter, child: bounded),
              ),
            ),
        ],
      ),
    );
  }
}
