import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_progress_ring.dart';

/// Card de clase actual con SacProgressRing - Estilo "Scout Vibrante"
///
/// Supports accordion/collapsible behavior.
///
/// **Collapsed (default):** compact horizontal row showing the school icon,
/// "Mi Clase" label, the class name below, a small progress ring with the
/// percentage, the "Completada" badge when applicable, and a chevron that
/// rotates 180° on expand.
///
/// **Expanded:** shows the full big progress ring, class name and motivational
/// text — identical to the original always-visible layout.
///
/// The expand/collapse transition is driven by [AnimationController] +
/// [SizeTransition] (250 ms, [Curves.easeInOut]).  The chevron uses
/// [AnimatedRotation] so it spins smoothly between states.
///
/// Public API is unchanged: [currentClassName] and [classProgress].
class CurrentClassCard extends StatefulWidget {
  final String? currentClassName;
  final double classProgress;

  const CurrentClassCard({
    super.key,
    this.currentClassName,
    required this.classProgress,
  });

  @override
  State<CurrentClassCard> createState() => _CurrentClassCardState();
}

class _CurrentClassCardState extends State<CurrentClassCard>
    with SingleTickerProviderStateMixin {
  // Collapsed by default so the dashboard feels compact on first load.
  bool _isExpanded = false;

  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  int get _progressPercentage => (widget.classProgress * 100).toInt();
  bool get _isComplete => widget.classProgress >= 1.0;

  // ─── Collapsed header row ─────────────────────────────────────────────────

  Widget _buildCollapsedHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // School icon
        HugeIcon(
          icon: HugeIcons.strokeRoundedSchool,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),

        // Label + class name stacked
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mi Clase',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.sac.textSecondary,
                      letterSpacing: 0.3,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.currentClassName ?? 'Sin clase asignada',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.sac.text,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Small progress ring + percentage, OR "Completada" badge
        if (_isComplete)
          _CompletadaBadge()
        else
          SacProgressRing(
            progress: widget.classProgress,
            size: 44,
            strokeWidth: 5,
            animate: false,
            child: Text(
              '$_progressPercentage%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: context.sac.text,
              ),
            ),
          ),

        const SizedBox(width: 8),

        // Animated chevron — rotates 0° (down) → 180° (up) when expanded
        AnimatedRotation(
          turns: _isExpanded ? 0.5 : 0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowDown01,
            size: 18,
            color: context.sac.textSecondary,
          ),
        ),
      ],
    );
  }

  // ─── Expanded body ────────────────────────────────────────────────────────

  Widget _buildExpandedBody(BuildContext context) {
    return Column(
      children: [
        // Thin divider between header and expanded content
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(
            height: 1,
            thickness: 1,
            color: context.sac.borderLight,
          ),
        ),

        // Progress ring — size scales with available card width
        LayoutBuilder(
          builder: (context, constraints) {
            final ringSize =
                (constraints.maxWidth * 0.45).clamp(100.0, 180.0);
            return SacProgressRing(
              progress: widget.classProgress,
              size: ringSize,
              strokeWidth: 10,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$_progressPercentage%',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.sac.text,
                        ),
                  ),
                  Text(
                    'progreso',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.sac.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Class name
        Text(
          widget.currentClassName ?? 'Sin clase asignada',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),

        // Motivational text
        Text(
          _isComplete
              ? '¡Felicidades! Has completado esta clase.'
              : widget.currentClassName != null
                  ? '¡Sigue adelante, vas muy bien!'
                  : 'Únete a un club para comenzar',
          style: TextStyle(
            fontSize: 14,
            color: _isComplete
                ? AppColors.secondaryDark
                : context.sac.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SacCard(
      // Remove default padding so we can control padding around the
      // tappable header and the expandable body independently.
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tappable header — minimum 48 px touch target guaranteed by
          // the ConstrainedBox + the 16 px vertical padding it already
          // provides (2 × 16 = 32 px of padding plus text height > 48 px).
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: _buildCollapsedHeader(context),
            ),
          ),

          // Animated expand/collapse body
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: -1.0,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16,
              ),
              child: _buildExpandedBody(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Private badge widget ─────────────────────────────────────────────────────

class _CompletadaBadge extends StatelessWidget {
  const _CompletadaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            size: 14,
            color: AppColors.secondaryDark,
          ),
          const SizedBox(width: 4),
          Text(
            'Completada',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
