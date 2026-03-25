import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

import '../../domain/entities/honor.dart';
import '../../domain/entities/user_honor.dart';

/// Unified honor card for both catalog and my-honors views.
///
/// Renders all 6 states:
/// - Available (not enrolled): no border-left, chevron-right
/// - Inscripto: blue border-left, "Inscripta — sin evidencia"
/// - En progreso: red border-left, "En progreso"
/// - Enviado: yellow border-left, "Enviada — en revision"
/// - Validado: green border-left, gold star badge
/// - Rechazado: red border-left, "Rechazada"
class HonorCard extends StatelessWidget {
  final Honor honor;
  final UserHonor? userHonor;
  final VoidCallback onTap;

  const HonorCard({
    super.key,
    required this.honor,
    this.userHonor,
    required this.onTap,
  });

  bool get _isEnrolled => userHonor != null;
  bool get _isCompleted => userHonor?.isCompleted ?? false;
  String? get _displayStatus => userHonor?.displayStatus;
  Color? get _statusColor => userHonor?.statusColor;

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
              color: const Color(0xFFFAFBFB),
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
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      _isEnrolled ? 15 : 12, // Extra left padding for border
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
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.sacBlack,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_isEnrolled && _displayStatus != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  userHonor!.statusLabel,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconArea() {
    if (_isCompleted) {
      // Validado: solid green with white checkmark
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.sacGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: 24,
        ),
      );
    }

    // Enrolled states: light tinted background with honor image
    // Available: #F0F4F5 background with honor image
    final bgColor = _isEnrolled
        ? _statusColor!.withAlpha(25)
        : const Color(0xFFF0F4F5);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: honor.imageUrl != null && honor.imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: honor.imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  Icons.emoji_events_outlined,
                  color: _statusColor ?? AppColors.sacGrey,
                  size: 22,
                ),
              ),
            )
          : Icon(
              Icons.emoji_events_outlined,
              color: _statusColor ?? AppColors.sacGrey,
              size: 22,
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
