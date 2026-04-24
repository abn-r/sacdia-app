import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Attendees section — read-only display of activity participants.
///
/// Shows stacked circular avatars with warm, distinct colors for initials.
/// The list comes from the `attendees` JSON field on the activity; users are
/// auto-enrolled when the activity is created (no opt-in needed).
class ActivityAttendeesSection extends StatelessWidget {
  final List<String> attendees;

  const ActivityAttendeesSection({super.key, required this.attendees});

  static const int _maxVisible = 5;

  // Warm, distinct color palette for avatar initials
  static const List<Color> _warmPalette = [
    Color(0xFFF59E0B), // amber-500
    Color(0xFFF43F5E), // rose-500
    Color(0xFF0EA5E9), // sky-500
    Color(0xFF8B5CF6), // violet-500
    Color(0xFF10B981), // emerald-500
    Color(0xFFEF4444), // red-500
    Color(0xFF3B82F6), // blue-500
    Color(0xFFEC4899), // pink-500
  ];

  static const List<Color> _warmPaletteDark = [
    Color(0xFFD97706), // amber-600
    Color(0xFFE11D48), // rose-600
    Color(0xFF0284C7), // sky-600
    Color(0xFF7C3AED), // violet-600
    Color(0xFF059669), // emerald-600
    Color(0xFFDC2626), // red-600
    Color(0xFF2563EB), // blue-600
    Color(0xFFDB2777), // pink-600
  ];

  @override
  Widget build(BuildContext context) {
    final sac = context.sac;
    final count = attendees.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'activities.widgets.attendees_title'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 8),
            // Count badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (count == 0)
          Text(
            'activities.widgets.attendees_all'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: sac.textSecondary,
                ),
          )
        else
          _StackedAvatars(
            attendees: attendees,
            maxVisible: _maxVisible,
            warmPalette: _warmPalette,
            warmPaletteDark: _warmPaletteDark,
          ),
      ],
    );
  }
}

// ── _StackedAvatars ────────────────────────────────────────────────────────────

class _StackedAvatars extends StatelessWidget {
  final List<String> attendees;
  final int maxVisible;
  final List<Color> warmPalette;
  final List<Color> warmPaletteDark;

  const _StackedAvatars({
    required this.attendees,
    required this.maxVisible,
    required this.warmPalette,
    required this.warmPaletteDark,
  });

  static const double _avatarSize = 36.0;
  // Tighter overlap: 8px visible gap between avatars
  static const double _overlap = 8.0;

  @override
  Widget build(BuildContext context) {
    final visible = attendees.length > maxVisible
        ? attendees.sublist(0, maxVisible)
        : attendees;
    final overflow = attendees.length - visible.length;

    final totalItems = visible.length + (overflow > 0 ? 1 : 0);
    final totalWidth =
        _avatarSize + (totalItems - 1) * (_avatarSize - _overlap);

    return SizedBox(
      height: _avatarSize,
      width: totalWidth,
      child: Stack(
        children: [
          // Render avatars in reverse order so index 0 is on top
          for (int i = visible.length - 1; i >= 0; i--)
            Positioned(
              left: i * (_avatarSize - _overlap),
              child: _AvatarCircle(
                index: i,
                userId: visible[i],
                size: _avatarSize,
                warmPalette: warmPalette,
                warmPaletteDark: warmPaletteDark,
              ),
            ),
          // Overflow "+N" indicator
          if (overflow > 0)
            Positioned(
              left: visible.length * (_avatarSize - _overlap),
              child: _OverflowCircle(count: overflow, size: _avatarSize),
            ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final int index;
  final String userId;
  final double size;
  final List<Color> warmPalette;
  final List<Color> warmPaletteDark;

  const _AvatarCircle({
    required this.index,
    required this.userId,
    required this.size,
    required this.warmPalette,
    required this.warmPaletteDark,
  });

  Color _bgColor() => warmPalette[index % warmPalette.length].withValues(alpha: 0.18);
  Color _textColor() => warmPaletteDark[index % warmPaletteDark.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _bgColor(),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          userId.isNotEmpty ? userId[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: _textColor(),
          ),
        ),
      ),
    );
  }
}

class _OverflowCircle extends StatelessWidget {
  final int count;
  final double size;

  const _OverflowCircle({required this.count, required this.size});

  @override
  Widget build(BuildContext context) {
    final sac = context.sac;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: sac.surfaceVariant,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: TextStyle(
            fontSize: size * 0.30,
            fontWeight: FontWeight.w700,
            color: sac.textSecondary,
          ),
        ),
      ),
    );
  }
}
