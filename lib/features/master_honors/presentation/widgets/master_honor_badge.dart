import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/user_master_honor.dart';

/// Badge visual de maestría para usar en la tarjeta virtual y en listas
/// de perfil.
class MasterHonorBadge extends StatelessWidget {
  final UserMasterHonor honor;
  final bool compact;
  final bool showStatus;

  const MasterHonorBadge({
    super.key,
    required this.honor,
    this.compact = true,
    this.showStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = honor.isCurrent;
    final status = _statusLabel(honor);
    final initials = _initials(honor.name);

    return Container(
      width: compact ? 128 : 150,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _badgeColor(context, isCurrent).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _badgeColor(context, isCurrent).withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _HonorImage(
                imageUrl: honor.masterImage,
                initials: initials,
                height: compact ? 26 : 30,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  honor.name,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 12 : 13,
                  ),
                ),
              ),
            ],
          ),
          if (showStatus) ...[
            const SizedBox(height: 6),
            _MasterHonorStatusBadge(
              label: status,
              isCurrent: isCurrent,
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(UserMasterHonor honor) {
    if (honor.displayStatusLabel.trim().isNotEmpty) {
      return honor.displayStatusLabel;
    }
    return honor.isCurrent ? 'Vigente' : 'No vigente';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  Color _badgeColor(BuildContext context, bool isCurrent) {
    if (isCurrent) {
      return AppColors.secondary;
    }
    return AppColors.error;
  }
}

class _HonorImage extends StatelessWidget {
  const _HonorImage({
    required this.imageUrl,
    required this.initials,
    required this.height,
  });

  final String? imageUrl;
  final String initials;
  final double height;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim() ?? '';
    final width = height * 1.25;

    final fallback = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: height * 0.4,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkText
              : AppColors.lightText,
        ),
      ),
    );

    if (image.isEmpty) {
      return fallback;
    }

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SacNetworkImage(
          imageUrl: image,
          fit: BoxFit.contain,
          memCacheWidth: (width * 3).round(),
          memCacheHeight: (height * 3).round(),
          errorWidget: (_, __, ___) => fallback,
          placeholder: (_, __) => fallback,
        ),
      ),
    );
  }
}

class _MasterHonorStatusBadge extends StatelessWidget {
  final String label;
  final bool isCurrent;

  const _MasterHonorStatusBadge({
    required this.label,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor =
        isCurrent ? AppColors.secondaryLight : AppColors.errorLight;
    final labelColor =
        isCurrent ? AppColors.secondaryDark : AppColors.errorDark;

    return Container(
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 4,
        horizontal: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isCurrent) ...[
            HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              size: 13,
              color: labelColor,
            ),
            const SizedBox(width: 4),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 76),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: labelColor,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
