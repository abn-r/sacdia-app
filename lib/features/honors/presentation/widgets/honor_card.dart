import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/honor.dart';
import '../../domain/entities/user_honor.dart';

/// Unified honor card for both catalog and my-honors views.
///
/// Renders all 6 states:
/// - Available (not enrolled): no border-left, chevron-right
/// - inscrito: blue border-left, "inscrita — sin evidencia"
/// - En progreso: red border-left, "En progreso"
/// - Enviado: yellow border-left, "Enviada — en revision"
/// - Validado: green border-left, gold star badge
/// - Rechazado: red border-left, "Rechazada"
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
  Color? get _statusColor => userHonor?.statusColor;

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
              child: Stack(
                children: [
                  // Border-left indicator
                  if (_isEnrolled)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 3,
                        color: _statusColor,
                      ),
                    ),

                  // Card content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          _isEnrolled
                              ? 15
                              : 12, // Extra left padding for border
                          12,
                          12,
                          12,
                        ),
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
                                  if (_isEnrolled &&
                                      _displayStatus != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      _isCompleted
                                          ? 'honors.card.completed_label'.tr()
                                          : userHonor!.statusLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _statusColor,
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
    // Left offset matches the enrolled border (3px) so the bar starts at the
    // same horizontal position as the card content.
    const double leftPad = 15.0;

    return Padding(
      padding: const EdgeInsets.only(
        left: leftPad,
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
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.secondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconArea() {
    // Oval dimensions: wider than tall (eye/patch shape)
    const double iconWidth = 58.0;
    const double iconHeight = 44.0;
    final borderRadius = BorderRadius.all(
      Radius.elliptical(iconWidth / 2, iconHeight / 2),
    );

    // Always show the honor image, with a check overlay when completed
    final imageWidget = honor.imageUrl != null && honor.imageUrl!.isNotEmpty
        ? ClipRRect(
            borderRadius: borderRadius,
            child: SizedBox(
              width: iconWidth,
              height: iconHeight,
              child: CachedNetworkImage(
                imageUrl: honor.imageUrl!,
                memCacheWidth: 174,  // 58 * 3 (max device pixel ratio)
                memCacheHeight: 132, // 44 * 3
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFFF0F4F5),
                  child: Icon(
                    Icons.emoji_events_outlined,
                    color: _statusColor ?? AppColors.sacGrey,
                    size: 24,
                  ),
                ),
              ),
            ),
          )
        : Container(
            width: iconWidth,
            height: iconHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F5),
              borderRadius: borderRadius,
            ),
            child: Icon(
              Icons.emoji_events_outlined,
              color: _statusColor ?? AppColors.sacGrey,
              size: 24,
            ),
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
                color: AppColors.sacGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(
                Icons.check_rounded,
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
          color: AppColors.sacYellow,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.star_rounded,
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
    return const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.sacGrey,
      size: 24,
    );
  }
}
