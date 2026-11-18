import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_style.dart';

import '../../domain/entities/monthly_report.dart';

/// Única fuente del color, ícono y nombre de cada estado de un informe.
///
/// Borrador = advertencia, Generado = acento de la app, En revisión = info,
/// Aprobado = éxito, Rechazado = error. Cada uno lleva su ícono y su texto: el
/// color nunca es la única señal. La usan el chip de las listas y el panel del
/// detalle.
SacStatusStyle monthlyReportStatusStyle(
  BuildContext context,
  MonthlyReportStatus status,
) {
  final c = context.sac;
  final label = status.label;
  switch (status) {
    case MonthlyReportStatus.draft:
      return SacStatusStyle(
        kind: SacStatusKind.pending,
        container: c.warningContainer,
        onContainer: c.onWarningContainer,
        solid: c.warning,
        icon: HugeIcons.strokeRoundedNoteEdit,
        label: label,
      );
    case MonthlyReportStatus.generated:
      final accent = SacAccent.of(context);
      final dark = Theme.brightnessOf(context) == Brightness.dark;
      return SacStatusStyle(
        kind: SacStatusKind.pending,
        container: dark
            ? Color.alphaBlend(accent.color.withValues(alpha: 0.2), c.surface)
            : accent.light,
        onContainer:
            dark ? accent.forHighContrast(Brightness.dark).color : accent.dark,
        solid: accent.color,
        icon: HugeIcons.strokeRoundedFile01,
        label: label,
      );
    case MonthlyReportStatus.submitted:
      return SacStatusStyle(
        kind: SacStatusKind.review,
        container: c.infoContainer,
        onContainer: c.onInfoContainer,
        solid: c.info,
        icon: HugeIcons.strokeRoundedClock01,
        label: label,
      );
    case MonthlyReportStatus.approved:
      return SacStatusStyle(
        kind: SacStatusKind.validated,
        container: c.successContainer,
        onContainer: c.onSuccessContainer,
        solid: c.success,
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        label: label,
      );
    case MonthlyReportStatus.rejected:
      return SacStatusStyle(
        kind: SacStatusKind.rejected,
        container: c.errorContainer,
        onContainer: c.onErrorContainer,
        solid: c.error,
        icon: HugeIcons.strokeRoundedAlertCircle,
        label: label,
      );
  }
}

/// Chip de estado de un informe mensual (ícono + texto).
class MonthlyReportStatusChip extends StatelessWidget {
  const MonthlyReportStatusChip({super.key, required this.status});

  final MonthlyReportStatus status;

  @override
  Widget build(BuildContext context) {
    final style = monthlyReportStatusStyle(context, status);
    return SacBadge(
      label: style.label,
      icon: style.icon,
      backgroundColor: style.container,
      foregroundColor: style.onContainer,
    );
  }
}
