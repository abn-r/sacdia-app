import 'package:flutter/material.dart';

import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_tone.dart';

/// Result chip (icon + text + tone): «Aprobada», «Rechazada», «Seguro sin
/// verificar», «Sin tallas activas». A thin map from [SacTone] to [SacBadge],
/// so every supervision screen draws results the same way. The text is what
/// a screen reader says; the icon and the tint only reinforce it.
class SupervisionStatusChip extends StatelessWidget {
  const SupervisionStatusChip({
    super.key,
    required this.label,
    required this.icon,
    this.tone = SacTone.muted,
  });

  /// Already translated.
  final String label;
  final HugeIconData icon;
  final SacTone tone;

  @override
  Widget build(BuildContext context) {
    final variant = switch (tone) {
      SacTone.accent => SacBadgeVariant.primary,
      SacTone.success => SacBadgeVariant.secondary,
      SacTone.warning => SacBadgeVariant.accent,
      SacTone.info => SacBadgeVariant.info,
      SacTone.muted => SacBadgeVariant.neutral,
      SacTone.error => SacBadgeVariant.error,
    };
    return SacBadge(label: label, icon: icon, variant: variant);
  }
}
