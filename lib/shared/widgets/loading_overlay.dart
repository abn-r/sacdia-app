import 'package:flutter/material.dart';

/// Overlay de carga reutilizable
///
/// Muestra un indicador de carga circular sobre un fondo semitransparente.
/// Se utiliza para indicar operaciones en progreso sin bloquear la UI subyacente.
class LoadingOverlay extends StatelessWidget {
  /// Indica si el overlay de carga debe mostrarse
  final bool isLoading;

  /// Widget hijo que se muestra debajo del overlay
  final Widget child;

  /// Color del fondo semitransparente
  final Color? barrierColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.barrierColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: barrierColor ?? Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
