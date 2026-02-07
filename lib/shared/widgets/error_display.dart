import 'package:flutter/material.dart';

/// Widget para mostrar errores de manera consistente
///
/// Proporciona una interfaz uniforme para mostrar mensajes de error
/// con opción de reintentar la operación.
class ErrorDisplay extends StatelessWidget {
  /// Mensaje de error a mostrar
  final String message;

  /// Callback al presionar el botón de reintentar
  final VoidCallback? onRetry;

  /// Icono a mostrar
  final IconData icon;

  /// Etiqueta del botón de reintentar
  final String retryLabel;

  const ErrorDisplay({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.retryLabel = 'Reintentar',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
