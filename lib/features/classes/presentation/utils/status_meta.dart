import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/class_requirement.dart';

/// Encapsula los tokens visuales (label, color, bg, dark) para cada
/// [RequirementStatus].
///
/// Uso:
/// ```dart
/// final meta = StatusMeta.of(RequirementStatus.observado);
/// Container(color: meta.bg, child: Text(meta.label, style: TextStyle(color: meta.dark)));
/// ```
class StatusMeta {
  final String label;

  /// Color base (dot, icon, borde).
  final Color color;

  /// Color de fondo suave.
  final Color bg;

  /// Color oscuro para texto sobre bg claro.
  final Color dark;

  const StatusMeta._({
    required this.label,
    required this.color,
    required this.bg,
    required this.dark,
  });

  /// Devuelve el [StatusMeta] correspondiente al [status] dado.
  static StatusMeta of(RequirementStatus status) {
    switch (status) {
      case RequirementStatus.validado:
        return const StatusMeta._(
          label: 'Validado',
          color: AppColors.validatedColor,
          bg: AppColors.validatedBg,
          dark: AppColors.validatedDark,
        );
      case RequirementStatus.enviado:
        return const StatusMeta._(
          label: 'Enviado',
          color: AppColors.sentColor,
          bg: AppColors.sentBg,
          dark: AppColors.sentDark,
        );
      case RequirementStatus.observado:
        return const StatusMeta._(
          label: 'Observado',
          color: AppColors.observedColor,
          bg: AppColors.observedBg,
          dark: AppColors.observedDark,
        );
      case RequirementStatus.rechazado:
        return const StatusMeta._(
          label: 'Rechazado',
          color: AppColors.rejectedColor,
          bg: AppColors.rejectedBg,
          dark: AppColors.rejectedDark,
        );
      case RequirementStatus.pendiente:
        return const StatusMeta._(
          label: 'Pendiente',
          color: AppColors.pendingColor,
          bg: AppColors.pendingBg,
          dark: AppColors.pendingDark,
        );
    }
  }
}
