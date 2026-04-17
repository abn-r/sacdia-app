import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Shimmer-style skeleton that mirrors the ActivityDetailView layout structure.
///
/// Uses an AnimationController for the shimmer sweep so the animation
/// is properly disposed when the widget leaves the tree.
class ActivityDetailSkeleton extends StatefulWidget {
  const ActivityDetailSkeleton({super.key});

  @override
  State<ActivityDetailSkeleton> createState() => _ActivityDetailSkeletonState();
}

class _ActivityDetailSkeletonState extends State<ActivityDetailSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _shimmer = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) => CustomScrollView(
        slivers: [
          // AppBar placeholder (back button + title)
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: context.sac.text,
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero block
                _SkeletonBox(
                  width: double.infinity,
                  height: 220,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  shimmerValue: _shimmer.value,
                ),
                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title line
                      _SkeletonBox(
                        width: 240,
                        height: 22,
                        shimmerValue: _shimmer.value,
                      ),
                      const SizedBox(height: 8),
                      // Type chip + platform badge — grouped left
                      Row(
                        children: [
                          _SkeletonBox(
                            width: 68,
                            height: 22,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(8)),
                            shimmerValue: _shimmer.value,
                          ),
                          const SizedBox(width: 6),
                          _SkeletonBox(
                            width: 80,
                            height: 22,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(8)),
                            shimmerValue: _shimmer.value,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Meta line (countdown · section)
                      _SkeletonBox(
                        width: 180,
                        height: 14,
                        shimmerValue: _shimmer.value,
                      ),
                      const SizedBox(height: 16),

                      // Info strip (single card, fecha + hora)
                      _SkeletonBox(
                        width: double.infinity,
                        height: 68,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(14)),
                        shimmerValue: _shimmer.value,
                      ),
                      const SizedBox(height: 10),

                      // Location row
                      _SkeletonBox(
                        width: double.infinity,
                        height: 56,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(14)),
                        shimmerValue: _shimmer.value,
                      ),
                      const SizedBox(height: 24),

                      // Description header
                      _SkeletonBox(
                        width: 120,
                        height: 18,
                        shimmerValue: _shimmer.value,
                      ),
                      const SizedBox(height: 10),
                      // Description lines
                      _SkeletonBox(
                        width: double.infinity,
                        height: 14,
                        shimmerValue: _shimmer.value,
                      ),
                      const SizedBox(height: 6),
                      _SkeletonBox(
                        width: double.infinity,
                        height: 14,
                        shimmerValue: _shimmer.value,
                      ),
                      const SizedBox(height: 6),
                      _SkeletonBox(
                        width: 180,
                        height: 14,
                        shimmerValue: _shimmer.value,
                      ),
                      const SizedBox(height: 24),

                      // Attendees header
                      _SkeletonBox(
                        width: 140,
                        height: 18,
                        shimmerValue: _shimmer.value,
                      ),
                      const SizedBox(height: 12),
                      // Avatar row
                      Row(
                        children: List.generate(
                          5,
                          (i) => Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                            child: _SkeletonBox(
                              width: 36,
                              height: 36,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(100),
                              ),
                              shimmerValue: _shimmer.value,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Creator footer
                      Row(
                        children: [
                          _SkeletonBox(
                            width: 24,
                            height: 24,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(100),
                            ),
                            shimmerValue: _shimmer.value,
                          ),
                          const SizedBox(width: 8),
                          _SkeletonBox(
                            width: 160,
                            height: 12,
                            shimmerValue: _shimmer.value,
                          ),
                        ],
                      ),

                      // Bottom spacing for the fixed action bar
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

// ── _SkeletonBox ──────────────────────────────────────────────────────────────

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final double shimmerValue;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    required this.shimmerValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE8EDF2);
    final highlightColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFF5F8FB);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment(shimmerValue - 1, 0),
          end: Alignment(shimmerValue + 1, 0),
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
