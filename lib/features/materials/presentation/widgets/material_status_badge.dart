import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/material_status.dart';

/// Badge visual para el estado de una orden de materiales.
///
/// Paleta alineada con el admin panel (AppColors únicamente):
/// - en_revision → muted (ink400 bg / ink600 text)
/// - aprobada    → warning (accentLight bg / accentDark text)
/// - pagada      → success (secondaryLight bg / secondaryDark text)
/// - entregada   → success (mismo que pagada)
/// - cancelada   → destructive (errorLight bg / errorDark text)
class MaterialStatusBadge extends StatelessWidget {
  final MaterialStatus status;

  const MaterialStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _resolve(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  static (Color bg, Color fg, String label) _resolve(MaterialStatus status) {
    switch (status) {
      case MaterialStatus.enRevision:
        return (AppColors.ink100, AppColors.ink600, 'En revisión');
      case MaterialStatus.aprobada:
        return (AppColors.accentLight, AppColors.accentDark, 'Aprobada');
      case MaterialStatus.pagada:
        return (AppColors.secondaryLight, AppColors.secondaryDark, 'Pagada');
      case MaterialStatus.entregada:
        return (AppColors.secondaryLight, AppColors.secondaryDark, 'Entregada');
      case MaterialStatus.cancelada:
        return (AppColors.errorLight, AppColors.errorDark, 'Cancelada');
    }
  }
}
