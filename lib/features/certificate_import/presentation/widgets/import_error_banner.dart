import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Inline error that appears above an action without closing its container.
///
/// Enters with [SacMotion.standard] and leaves with [SacMotion.reducedFade]
/// (asymmetric, ease-out). Reduced Motion keeps the fade and drops the resize.
class ImportErrorBanner extends StatelessWidget {
  const ImportErrorBanner({super.key, required this.message});

  /// Translated text to show, or `null` to hide the banner.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final text = message;
    final content = AnimatedSwitcher(
      duration: text == null ? SacMotion.reducedFade : SacMotion.standard,
      switchInCurve: SacMotion.easeOut,
      switchOutCurve: SacMotion.easeOut,
      child: text == null
          ? const SizedBox(key: ValueKey('import-error-none'), width: 0)
          : Semantics(
              key: const ValueKey('import-error-banner'),
              liveRegion: true,
              container: true,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.error,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
    );
    // AnimatedSize with a zero duration re-dirties its own layout, so under
    // Reduced Motion the resize is dropped instead of zeroed.
    if (reduce) return content;
    return AnimatedSize(
      duration: SacMotion.standard,
      curve: SacMotion.easeOut,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}
