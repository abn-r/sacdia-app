import 'package:flutter/material.dart';

/// Widget para mostrar estados vacíos de manera consistente
///
/// Se utiliza cuando no hay datos disponibles, con opción
/// de ejecutar una acción como agregar un nuevo elemento.
class EmptyStateWidget extends StatelessWidget {
  /// Mensaje a mostrar
  final String message;

  /// Icono a mostrar
  final IconData icon;

  /// Etiqueta del botón de acción opcional
  final String? actionLabel;

  /// Callback al presionar el botón de acción
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.icon = Icons.inbox,
    this.actionLabel,
    this.onAction,
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
            Icon(
              icon,
              size: 80,
              color: theme.colorScheme.secondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
