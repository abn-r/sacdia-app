import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

import '../../theme/sac_colors.dart';

/// Generic status of an item. Features map their own statuses onto it.
enum SacStatusKind { pending, review, rejected, validated }

/// Colors, icon and label for one [SacStatusKind]. One source for rows,
/// the status bar and the status panel.
class SacStatusStyle {
  const SacStatusStyle({
    required this.kind,
    required this.container,
    required this.onContainer,
    required this.solid,
    required this.icon,
    required this.label,
  });

  /// Resolves colors from the theme. [label] is already translated; [icon]
  /// overrides the default icon of the kind.
  factory SacStatusStyle.of(
    BuildContext context,
    SacStatusKind kind, {
    required String label,
    HugeIconData? icon,
  }) {
    final c = context.sac;
    switch (kind) {
      case SacStatusKind.pending:
        return SacStatusStyle(
          kind: kind,
          container: c.surfaceVariant,
          onContainer: c.textSecondary,
          solid: c.textTertiary.withValues(alpha: 0.45),
          icon: icon ?? HugeIcons.strokeRoundedFolder01,
          label: label,
        );
      case SacStatusKind.rejected:
        return SacStatusStyle(
          kind: kind,
          container: c.errorContainer,
          onContainer: c.onErrorContainer,
          solid: c.error,
          icon: icon ?? HugeIcons.strokeRoundedAlertCircle,
          label: label,
        );
      case SacStatusKind.review:
        return SacStatusStyle(
          kind: kind,
          container: c.infoContainer,
          onContainer: c.onInfoContainer,
          solid: c.info,
          icon: icon ?? HugeIcons.strokeRoundedSent,
          label: label,
        );
      case SacStatusKind.validated:
        return SacStatusStyle(
          kind: kind,
          container: c.successContainer,
          onContainer: c.onSuccessContainer,
          solid: c.success,
          icon: icon ?? HugeIcons.strokeRoundedCheckmarkCircle02,
          label: label,
        );
    }
  }

  final SacStatusKind kind;

  /// Tinted background (row icon, status panel).
  final Color container;

  /// Text and icons on [container], and status text on surface.
  final Color onContainer;

  /// Solid fill for the progress bar and timeline dots.
  final Color solid;

  final HugeIconData icon;
  final String label;
}
