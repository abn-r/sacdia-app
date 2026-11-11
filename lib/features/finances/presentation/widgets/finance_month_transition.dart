import 'package:flutter/material.dart';

import '../../../../core/animations/motion_tokens.dart';
import 'balance_header_card.dart' show kFinanceStaleOpacity;

/// Contenido de Finanzas bajo el encabezado, durante un cambio de mes.
///
/// - Mientras el mes nuevo carga ([isStale]) el contenido del mes anterior
///   sigue visible pero atenuado.
/// - Cuando [monthKey] cambia (llegaron los datos del mes nuevo) el contenido
///   entra deslizándose desde el lado hacia el que se viaja ([direction] > 0:
///   mes posterior, entra por la derecha; < 0: por la izquierda) mientras se
///   desatenúa. Con movimiento reducido solo hay fundido, sin desplazamiento.
///
/// El primer [monthKey] no anima: no hay nada de dónde venir.
class FinanceMonthTransition extends StatefulWidget {
  const FinanceMonthTransition({
    super.key,
    required this.monthKey,
    required this.direction,
    required this.isStale,
    required this.child,
  });

  /// Identifica los datos mostrados; al cambiar se dispara la entrada.
  final Object monthKey;

  /// Sentido del viaje: positivo hacia un mes posterior.
  final int direction;

  final bool isStale;
  final Widget child;

  /// Desplazamiento inicial como fracción del ancho del contenido.
  static const double slideFraction = 0.06;

  static const Duration slideDuration = Duration(milliseconds: 240);

  @override
  State<FinanceMonthTransition> createState() => _FinanceMonthTransitionState();
}

class _FinanceMonthTransitionState extends State<FinanceMonthTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FinanceMonthTransition.slideDuration,
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(FinanceMonthTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.monthKey != oldWidget.monthKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    final dx = widget.direction >= 0
        ? FinanceMonthTransition.slideFraction
        : -FinanceMonthTransition.slideFraction;

    final Widget content = reduce
        ? widget.child
        : SlideTransition(
            position: Tween<Offset>(
              begin: Offset(dx, 0),
              end: Offset.zero,
            ).animate(_curve),
            child: widget.child,
          );

    return AnimatedOpacity(
      opacity: widget.isStale ? kFinanceStaleOpacity : 1,
      duration: reduce
          ? SacMotion.reducedFade
          : widget.isStale
              ? SacMotion.standard
              : FinanceMonthTransition.slideDuration,
      curve: Curves.easeOutCubic,
      child: content,
    );
  }
}
