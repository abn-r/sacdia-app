import 'dart:io';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

/// Widget para seleccionar y mostrar la foto de perfil.
///
/// Estilo "Scout Vibrante": círculo 120px con borde punteado indigo,
/// dos cards para cámara/galería, preview con overlay de edición.
class ProfilePhotoPicker extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickFromGallery;
  final VoidCallback? onConfirm;
  final VoidCallback? onRemove;
  final bool isUploading;

  const ProfilePhotoPicker({
    super.key,
    this.imagePath,
    required this.onTakePhoto,
    required this.onPickFromGallery,
    this.onConfirm,
    this.onRemove,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 14),

        // Title
        Text(
          'post_registration.photo.title'.tr(),
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'post_registration.photo.subtitle'.tr(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.sac.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),

        // Photo circle
        if (imagePath != null) ...[
          // Preview with overlay
          GestureDetector(
            onTap: isUploading ? null : onPickFromGallery,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (isUploading)
                  Container(
                    width: 200,
                    height: 200,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x80000000),
                    ),
                    child: const Center(
                      child: SacLoadingSmall(),
                    ),
                  )
                else
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.sac.surface, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: context.sac.shadow,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedEdit02,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Remove button
          if (onRemove != null && !isUploading)
            TextButton.icon(
              onPressed: onRemove,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.errorLight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                size: 18,
                color: AppColors.error,
              ),
              label: Text(
                'post_registration.photo.remove'.tr(),
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ] else ...[
          // Dashed circle placeholder
          GestureDetector(
            onTap: onPickFromGallery,
            // RepaintBoundary evita que Impeller propague opacidad heredada al CustomPaint
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _DashedCirclePainter(color: AppColors.primary),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedCamera01,
                        size: 40,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'post_registration.photo.add'.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        // Action cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: SacCard(
                  onTap: isUploading ? null : onTakePhoto,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCamera01,
                        size: 28,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'post_registration.photo.take'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.sac.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SacCard(
                  onTap: isUploading ? null : onPickFromGallery,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCamera02,
                        size: 28,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'post_registration.photo.gallery'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.sac.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Painter para el borde punteado circular.
class _DashedCirclePainter extends CustomPainter {
  final Color color;

  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const dashCount = 24;
    const dashLength = 0.7; // fraction of arc

    final arcAngle = (2 * math.pi) / dashCount;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * arcAngle;
      final sweepAngle = arcAngle * dashLength;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
