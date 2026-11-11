import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_pressable.dart';
import 'service_credential_file_card.dart';

/// The document area of the upload form: a dashed «Agregar documento» tile
/// while no file is chosen, the file card (with a «Cambiar» action) after.
/// The error (missing or invalid file) is shown under it.
class ServiceCredentialDocumentField extends StatelessWidget {
  const ServiceCredentialDocumentField({
    super.key,
    required this.file,
    required this.onPick,
    this.errorText,
  });

  final ConsentEvidenceLocalFile? file;

  /// Opens the source sheet. Null disables the field (while submitting).
  final VoidCallback? onPick;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final current = file;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (current == null)
          _AddTile(onTap: onPick, hasError: errorText != null)
        else
          ServiceCredentialFileCard(file: current, onChange: onPick),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(
                errorText!,
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  color: c.error,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, required this.hasError});

  final VoidCallback? onTap;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final enabled = onTap != null;
    final label = 'service_credentials.upload.add_document'.tr();
    final helper = 'service_credentials.upload.add_document_helper'.tr();

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label. $helper',
      excludeSemantics: true,
      onTap: onTap,
      child: SacPressable(
        enabled: enabled,
        onTap: onTap,
        child: RepaintBoundary(
          child: CustomPaint(
            // Foreground: the tile fill would hide a background border.
            foregroundPainter: _DashedBorderPainter(
              color: hasError ? c.error : (enabled ? accent.color : c.border),
              radius: AppTheme.radiusSM,
            ),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 96),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedFileAttachment,
                    size: 26,
                    color: enabled ? accent.color : c.textTertiary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    helper,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      color: c.textSecondary,
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
}

/// Dashed rounded border, same look as the other dashed «add» tiles.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _stroke = 1.5;
  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        _stroke / 2,
        _stroke / 2,
        size.width - _stroke,
        size.height - _stroke,
      ),
      Radius.circular(radius),
    );
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
