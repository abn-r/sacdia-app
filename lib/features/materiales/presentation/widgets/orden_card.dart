import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/orden.dart';
import '../utils/money_format.dart';
import 'material_estado_badge.dart';

/// Card de resumen de una orden en el historial.
///
/// Muestra folio (o "Sin folio"), fecha, estado y total.
/// Al tocar navega a la pantalla de detalle.
class OrdenCard extends StatelessWidget {
  final Orden orden;
  final VoidCallback onTap;

  const OrdenCard({super.key, required this.orden, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folio = orden.folioReferencia ?? 'Sin folio';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    folio,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFamily: folio == 'Sin folio' ? null : 'monospace',
                      color: folio == 'Sin folio'
                          ? AppColors.lightTextTertiary
                          : AppColors.lightText,
                    ),
                  ),
                  MaterialEstadoBadge(estado: orden.estado),
                ],
              ),
              const SizedBox(height: 6),

              // ── Fecha ─────────────────────────────────────────────────────
              Text(
                _formatDate(orden.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // ── Total + arrow ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatMxn(orden.totalCentavos),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.lightTextTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}
