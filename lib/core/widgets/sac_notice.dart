import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_theme.dart';
import '../theme/sac_colors.dart';
import '../utils/icon_helper.dart';

/// Meaning of a [SacNotice]; picks the container token pair and default icon.
enum SacNoticeTone { info, success, warning, error }

/// Inline notice: tinted container with an icon and a message. The icon and
/// the text carry the meaning, never the color alone. No side stripe.
///
/// Use [liveRegion] for notices that appear after an action (an error after
/// submitting) so screen readers announce them.
class SacNotice extends StatelessWidget {
  const SacNotice({
    super.key,
    required this.text,
    this.tone = SacNoticeTone.info,
    this.icon,
    this.liveRegion = false,
  });

  final String text;
  final SacNoticeTone tone;

  /// Replaces the default icon of the [tone].
  final HugeIconData? icon;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final (Color background, Color foreground, HugeIconData glyph) =
        switch (tone) {
      SacNoticeTone.info => (
          c.infoContainer,
          c.onInfoContainer,
          HugeIcons.strokeRoundedInformationCircle,
        ),
      SacNoticeTone.success => (
          c.successContainer,
          c.onSuccessContainer,
          HugeIcons.strokeRoundedCheckmarkCircle02,
        ),
      SacNoticeTone.warning => (
          c.warningContainer,
          c.onWarningContainer,
          HugeIcons.strokeRoundedAlert02,
        ),
      SacNoticeTone.error => (
          c.errorContainer,
          c.onErrorContainer,
          HugeIcons.strokeRoundedAlertCircle,
        ),
    };

    return Semantics(
      liveRegion: liveRegion,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child:
                    HugeIcon(icon: icon ?? glyph, size: 18, color: foreground),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    color: foreground,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
