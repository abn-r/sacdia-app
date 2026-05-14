import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/material_estado.dart';
import '../../domain/entities/orden.dart';
import '../../domain/entities/orden_line.dart';
import '../providers/cancel_order_provider.dart';
import '../providers/orden_detail_provider.dart';
import '../utils/money_format.dart';
import '../widgets/material_estado_badge.dart';

/// Pantalla de revisión de una orden por folio o ID.
///
/// Muestra el estado actual, las líneas, los totales y las acciones
/// disponibles según el estado (cancelar, enlace a pago, etc.).
class OrdenReviewScreen extends ConsumerStatefulWidget {
  final String folioOrId;

  const OrdenReviewScreen({super.key, required this.folioOrId});

  @override
  ConsumerState<OrdenReviewScreen> createState() => _OrdenReviewScreenState();
}

class _OrdenReviewScreenState extends ConsumerState<OrdenReviewScreen> {
  @override
  Widget build(BuildContext context) {
    final ordenAsync = ref.watch(ordenDetailProvider(widget.folioOrId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del pedido'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(
              ordenDetailProvider(widget.folioOrId),
            ),
          ),
        ],
      ),
      body: ordenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(ordenDetailProvider(widget.folioOrId)),
        ),
        data: (orden) => _OrdenBody(orden: orden),
      ),
    );
  }
}

// ── Body when data loaded ──────────────────────────────────────────────────────

class _OrdenBody extends ConsumerWidget {
  final Orden orden;
  const _OrdenBody({required this.orden});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(ordenDetailProvider(orden.folioReferencia ?? orden.id)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Estado + folio ─────────────────────────────────────────────────
          Row(
            children: [
              MaterialEstadoBadge(estado: orden.estado),
              const SizedBox(width: 12),
              if (orden.folioReferencia != null)
                _FolioPill(folio: orden.folioReferencia!)
              else
                _FolioPill(folio: '—'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Creado el ${_formatDate(orden.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),

          // ── Banner en_revision ─────────────────────────────────────────────
          if (orden.estado == MaterialEstado.enRevision) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.statusInfoBgLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.statusInfoText, width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.statusInfoText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Solicitud en revisión por el campo local.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.statusInfoText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Líneas ─────────────────────────────────────────────────────────
          _SectionHeader(title: 'Productos'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.lightBorder),
            ),
            child: Column(
              children: [
                for (int i = 0; i < orden.lines.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _OrdenLineItem(line: orden.lines[i]),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Totales ────────────────────────────────────────────────────────
          _SectionHeader(title: 'Totales'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.lightBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _TotalRow(
                    label: 'Subtotal',
                    amount: orden.subtotalCentavos,
                    isTotal: false,
                  ),
                  const SizedBox(height: 6),
                  _TotalRow(
                    label: 'Envío',
                    amount: orden.envioCentavos,
                    isTotal: false,
                  ),
                  const Divider(height: 16),
                  _TotalRow(
                    label: 'Total',
                    amount: orden.totalCentavos,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Acción según estado ────────────────────────────────────────────
          _ActionCard(orden: orden),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

// ── Action card ────────────────────────────────────────────────────────────────

class _ActionCard extends ConsumerWidget {
  final Orden orden;
  const _ActionCard({required this.orden});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cancelState = ref.watch(cancelOrderProvider);

    switch (orden.estado) {
      case MaterialEstado.enRevision:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: cancelState.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.error),
                      ),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar pedido'),
              onPressed: cancelState.isLoading
                  ? null
                  : () => _confirmCancel(context, ref),
            ),
          ],
        );

      case MaterialEstado.aprobada:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: AppColors.accentDark, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Pedido aprobado',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu pedido fue aprobado. El campo local te enviará los datos de pago.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.accentDark,
                    ),
                  ),
                ],
              ),
            ),
            // TODO(PR13): replace with datos_pago route when available.
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: null, // disabled until PR13
              child: const Text('Subir comprobante de pago (próximamente)'),
            ),
          ],
        );

      case MaterialEstado.pagada:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_bottom,
                  color: AppColors.secondaryDark, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pago validado. Esperando entrega.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case MaterialEstado.entregada:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.secondaryDark, size: 40),
              const SizedBox(height: 8),
              Text(
                'Tu pedido fue entregado',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryDark,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case MaterialEstado.cancelada:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (orden.cancelReason != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Motivo de cancelación',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.errorDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      orden.cancelReason!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.errorDark,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => context.go(RouteNames.homeMateriales),
              child: const Text('Hacer un nuevo pedido'),
            ),
          ],
        );
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Estás seguro de que querés cancelar este pedido?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo (requerido)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un motivo de cancelación.')),
      );
      return;
    }

    final result = await ref.read(cancelOrderProvider.notifier).cancel(
          folioOrId: orden.folioReferencia ?? orden.id,
          reason: reason,
        );

    if (!context.mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.error,
          ),
        );
      },
      (_) {
        ref.invalidate(ordenDetailProvider(orden.folioReferencia ?? orden.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido cancelado.')),
        );
      },
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _FolioPill extends StatelessWidget {
  final String folio;
  const _FolioPill({required this.folio});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.ink100,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        folio,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.ink600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.lightText,
          ),
    );
  }
}

class _OrdenLineItem extends StatelessWidget {
  final OrdenLine line;
  const _OrdenLineItem({required this.line});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Letter placeholder
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              line.product.title.isNotEmpty
                  ? line.product.title[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  line.product.sku,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.lightTextTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${line.qty} × ${formatMxn(line.priceCentavos)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMxn(line.lineTotalCentavos),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final int amount;
  final bool isTotal;
  const _TotalRow({
    required this.label,
    required this.amount,
    required this.isTotal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
              : theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.lightTextSecondary,
                ),
        ),
        Text(
          formatMxn(amount),
          style: isTotal
              ? theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.lightTextSecondary,
                ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.lightTextTertiary),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el pedido',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.lightTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
