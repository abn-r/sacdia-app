import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../domain/entities/class_requirement.dart';
import '../utils/status_meta.dart';

/// Badge de color con icono que indica el estado de un requerimiento.
///
/// Se renderiza con [SacBadge] (tintas de estado del design system):
/// - pendiente  -> advertencia (amarillo)
/// - enviado    -> informacion (azul)
/// - validado   -> exito (verde)
/// - rechazado  -> error (rojo)
/// - observado  -> advertencia (distinguido por icono y etiqueta)
class RequirementStatusBadge extends StatelessWidget {
  final RequirementStatus status;

  const RequirementStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);

    // Transición al cambiar de estado (enviado → validado, etc.):
    // scale sutil + fade; con Reduced Motion cambia sin animación.
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : SacMotion.standard,
      switchInCurve: SacMotion.easeOut,
      switchOutCurve: SacMotion.easeOut,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: SacBadge(
        key: ValueKey<RequirementStatus>(status),
        label: _label,
        icon: _icon,
        variant: _variant,
      ),
    );
  }

  String get _label {
    switch (status) {
      case RequirementStatus.pendiente:
        return 'classes.status.pending'.tr();
      case RequirementStatus.enviado:
        return 'classes.status.sent'.tr();
      case RequirementStatus.validado:
        return 'classes.status.validated'.tr();
      case RequirementStatus.rechazado:
        return 'classes.status.rejected'.tr();
      case RequirementStatus.observado:
        return StatusMeta.of(status).label;
    }
  }

  SacBadgeVariant get _variant {
    switch (status) {
      case RequirementStatus.pendiente:
      case RequirementStatus.observado:
        return SacBadgeVariant.accent;
      case RequirementStatus.enviado:
        return SacBadgeVariant.info;
      case RequirementStatus.validado:
        return SacBadgeVariant.secondary;
      case RequirementStatus.rechazado:
        return SacBadgeVariant.error;
    }
  }

  HugeIconData get _icon {
    switch (status) {
      case RequirementStatus.pendiente:
        return HugeIcons.strokeRoundedClock01;
      case RequirementStatus.enviado:
        return HugeIcons.strokeRoundedSent;
      case RequirementStatus.validado:
        return HugeIcons.strokeRoundedCheckmarkCircle01;
      case RequirementStatus.rechazado:
        return HugeIcons.strokeRoundedCancel01;
      case RequirementStatus.observado:
        return HugeIcons.strokeRoundedInformationCircle;
    }
  }
}
