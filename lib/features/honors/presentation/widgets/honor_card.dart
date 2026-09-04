import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/honor.dart';
import '../../domain/entities/user_honor.dart';
import '../theme/honor_category_palette.dart';
import '../utils/user_honor_presentation_extensions.dart';
import 'honor_badge_image.dart';

/// Unified honor card for both catalog and my-honors views.
///
/// Renders all 6 states:
/// - Available (not enrolled): chevron-right
/// - Enrolled states: status label and progress use the honor category color.
/// - Validado: gold star badge.
///
/// When [progressPercentage] is provided and the user is enrolled, a thin
/// progress bar with an "X/Y" label is rendered at the bottom of the card.
/// Progress data must be passed from the parent — this widget never triggers
/// API calls on its own.
class HonorCard extends StatelessWidget {
  final Honor honor;
  final UserHonor? userHonor;
  final VoidCallback onTap;

  /// Fraction from 0.0 to 1.0. Only rendered when non-null and enrolled.
  final double? progressPercentage;

  /// Completed requirement count for the "X/Y" label.
  final int? completedCount;

  /// Total requirement count for the "X/Y" label.
  final int? totalRequirements;

  const HonorCard({
    super.key,
    required this.honor,
    this.userHonor,
    required this.onTap,
    this.progressPercentage,
    this.completedCount,
    this.totalRequirements,
  });

  bool get _isEnrolled => userHonor != null;
  bool get _isCompleted => userHonor?.isCompleted ?? false;
  String? get _displayStatus => userHonor?.displayStatus;

  Color get _categoryPaintColor => getCategoryPaintColor(
        categoryId: honor.categoryId != 0
            ? honor.categoryId
            : userHonor?.honorCategoryId,
        categoryName: honor.categoryName ?? userHonor?.honorCategoryName,
      );

  /// Whether the progress section should be shown.
  bool get _showProgress =>
      _isEnrolled &&
      progressPercentage != null &&
      completedCount != null &&
      totalRequirements != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: context.sac.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      children: [
                        // Icon area: 44x44
                        _buildIconArea(),
                        const SizedBox(width: 12),

                        // Text area
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                honor.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.sac.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_isEnrolled && _displayStatus != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  _isCompleted
                                      ? 'honors.card.completed_label'.tr()
                                      : userHonor!.statusLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _categoryPaintColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Trailing: gold star badge (validado) or chevron (available)
                        _buildTrailing(),
                      ],
                    ),
                  ),

                  // Progress section — only for enrolled honors with data
                  if (_showProgress) _buildProgressSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final double clampedValue = progressPercentage!.clamp(0.0, 1.0);
    final String label = '$completedCount/$totalRequirements';
    return Padding(
      padding: const EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: clampedValue,
                minHeight: 3,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(_categoryPaintColor),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _categoryPaintColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconArea() {
    // Give the badge a square-ish canvas and let the asset keep its natural
    // silhouette. Adventurer patches are often inverted triangles, so forcing
    // an oval/circle crops the real emblem.
    const double iconWidth = 58.0;
    const double iconHeight = 52.0;

    final imageWidget = HonorBadgeImage(
      imageUrl: honor.imageUrl,
      width: iconWidth,
      height: iconHeight,
      padding: const EdgeInsets.all(2),
      memCacheWidth: 174,
      memCacheHeight: 156,
      fallbackColor: _categoryPaintColor,
      fallbackIconSize: 24,
    );

    if (!_isCompleted) return imageWidget;

    // Completed: show image with a small green check badge overlay
    return SizedBox(
      width: iconWidth + 4,
      height: iconHeight + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: imageWidget),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedTick02,
                color: Colors.white,
                size: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailing() {
    if (_isCompleted) {
      // Gold star badge
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: const HugeIcon(
          icon: HugeIcons.strokeRoundedStar,
          color: Colors.white,
          size: 16,
        ),
      );
    }

    if (_isEnrolled) {
      // Status label is already shown — just show a subtle text
      return const SizedBox.shrink();
    }

    // Available: chevron
    return const HugeIcon(
      icon: HugeIcons.strokeRoundedArrowRight01,
      color: AppColors.pendingColor,
      size: 24,
    );
  }
}
