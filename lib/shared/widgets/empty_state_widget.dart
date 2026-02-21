import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

/// Widget para mostrar estados vacíos de manera consistente
///
/// Se utiliza cuando no hay datos disponibles, con opción
/// de ejecutar una acción como agregar un nuevo elemento.
class EmptyStateWidget extends StatelessWidget {
  /// Mensaje a mostrar
  final String message;

  /// Icono a mostrar (IconData o HugeIcons)
  final dynamic icon;

  /// Etiqueta del botón de acción opcional
  final String? actionLabel;

  /// Callback al presionar el botón de acción
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.icon = HugeIcons.strokeRoundedInbox,
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
            buildIcon(
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
                icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Colors.white, size: 20),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
