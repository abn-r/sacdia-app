import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/material_estado.dart';

/// Badge visual para el estado de una orden de materiales.
///
/// Paleta alineada con el admin panel (AppColors únicamente):
/// - en_revision → muted (ink400 bg / ink600 text)
/// - aprobada    → warning (accentLight bg / accentDark text)
/// - pagada      → success (secondaryLight bg / secondaryDark text)
/// - entregada   → success (mismo que pagada)
/// - cancelada   → destructive (errorLight bg / errorDark text)
class MaterialEstadoBadge extends StatelessWidget {
  final MaterialEstado estado;

  const MaterialEstadoBadge({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _resolve(estado);
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

  static (Color bg, Color fg, String label) _resolve(MaterialEstado estado) {
    switch (estado) {
      case MaterialEstado.enRevision:
        return (AppColors.ink100, AppColors.ink600, 'En revisión');
      case MaterialEstado.aprobada:
        return (AppColors.accentLight, AppColors.accentDark, 'Aprobada');
      case MaterialEstado.pagada:
        return (AppColors.secondaryLight, AppColors.secondaryDark, 'Pagada');
      case MaterialEstado.entregada:
        return (AppColors.secondaryLight, AppColors.secondaryDark, 'Entregada');
      case MaterialEstado.cancelada:
        return (AppColors.errorLight, AppColors.errorDark, 'Cancelada');
    }
  }
}
