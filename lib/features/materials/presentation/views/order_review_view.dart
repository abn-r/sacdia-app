import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/receipt.dart';
import '../../domain/entities/material_receipt_status.dart';
import '../../domain/entities/material_status.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_line.dart';
import '../providers/cancel_order_provider.dart';
import '../providers/receipts_provider.dart';
import '../providers/order_detail_provider.dart';
import '../utils/money_format.dart';
import '../widgets/material_status_badge.dart';

/// Pantalla de revisión de una orden por folio o ID.
///
/// Muestra el estado actual, las líneas, los totales y las acciones
/// disponibles según el estado (cancelar, enlace a pago, etc.).
class OrderReviewView extends ConsumerStatefulWidget {
  final String folioOrId;

  const OrderReviewView({super.key, required this.folioOrId});

  @override
  ConsumerState<OrderReviewView> createState() => _OrderReviewViewState();
}

class _OrderReviewViewState extends ConsumerState<OrderReviewView> {
  @override
  Widget build(BuildContext context) {
    final ordenAsync = ref.watch(orderDetailProvider(widget.folioOrId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del pedido'),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(
              orderDetailProvider(widget.folioOrId),
            ),
          ),
        ],
      ),
      body: ordenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: e.toString(),
          onRetry: () => ref.invalidate(orderDetailProvider(widget.folioOrId)),
        ),
        data: (order) => _OrdenBody(orden: order),
      ),
    );
  }
}

// ── Body when data loaded ──────────────────────────────────────────────────────

class _OrdenBody extends ConsumerWidget {
  final Order orden;
  const _OrdenBody({required this.orden});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => ref
          .invalidate(orderDetailProvider(orden.folioReferencia ?? orden.id)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Estado + folio ─────────────────────────────────────────────────
          Row(
            children: [
              MaterialStatusBadge(status: orden.status),
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
          if (orden.status == MaterialStatus.enRevision) ...[
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
                  const HugeIcon(
                      icon: HugeIcons.strokeRoundedInformationCircle,
                      size: 16,
                      color: AppColors.statusInfoText),
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

          // ── Comprobantes (aprobada / pagada / entregada) ───────────────────
          if (orden.status == MaterialStatus.aprobada ||
              orden.status == MaterialStatus.pagada ||
              orden.status == MaterialStatus.entregada) ...[
            _SectionHeader(title: 'Comprobantes'),
            const SizedBox(height: 8),
            _ComprobantesSection(folioOrId: orden.folioReferencia ?? orden.id),
            const SizedBox(height: 24),
          ],

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
  final Order orden;
  const _ActionCard({required this.orden});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cancelState = ref.watch(cancelOrderProvider);

    switch (orden.status) {
      case MaterialStatus.enRevision:
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
                  : const HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle),
              label: const Text('Cancelar pedido'),
              onPressed: cancelState.isLoading
                  ? null
                  : () => _confirmCancel(context, ref),
            ),
          ],
        );

      case MaterialStatus.aprobada:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                          color: AppColors.accentDark,
                          size: 20),
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
                    'Tu pedido fue aprobado. Realizá la transferencia y subí el comprobante.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.accentDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedBank),
              label: const Text('Ver datos de pago'),
              onPressed: () => context.push(
                RouteNames.materialsOrderPayment(
                    orden.folioReferencia ?? orden.id),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedFileUpload),
              label: const Text('Subir comprobante'),
              onPressed: () => context.push(
                RouteNames.materialsOrderReceipt(
                    orden.folioReferencia ?? orden.id),
              ),
            ),
          ],
        );

      case MaterialStatus.pagada:
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
              const HugeIcon(
                  icon: HugeIcons.strokeRoundedHourglass,
                  color: AppColors.secondaryDark,
                  size: 20),
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

      case MaterialStatus.entregada:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  color: AppColors.secondaryDark,
                  size: 40),
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

      case MaterialStatus.cancelada:
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
              onPressed: () => context.go(RouteNames.homeMaterials),
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
        ref.invalidate(orderDetailProvider(orden.folioReferencia ?? orden.id));
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
  final OrderLine line;
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
              ? theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)
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

// ── Comprobantes section ───────────────────────────────────────────────────────

/// Sección que muestra la lista de comprobantes de una orden.
/// Usa [receiptsProvider] para cargarlos de forma lazy.
class _ComprobantesSection extends ConsumerWidget {
  final String folioOrId;
  const _ComprobantesSection({required this.folioOrId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comprobantesAsync = ref.watch(receiptsProvider(folioOrId));

    return comprobantesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (receipts) {
        if (receipts.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.ink100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No hay comprobantes subidos aún.',
              style: TextStyle(color: AppColors.lightTextSecondary),
            ),
          );
        }
        return Column(
          children: [
            for (int i = 0; i < receipts.length; i++)
              Padding(
                padding:
                    EdgeInsets.only(bottom: i < receipts.length - 1 ? 8 : 0),
                child: _ComprobanteCard(comprobante: receipts[i]),
              ),
          ],
        );
      },
    );
  }
}

class _ComprobanteCard extends StatelessWidget {
  final Receipt comprobante;
  const _ComprobanteCard({required this.comprobante});

  Color get _statusColor {
    switch (comprobante.status) {
      case MaterialReceiptStatus.aprobado:
        return AppColors.secondaryDark;
      case MaterialReceiptStatus.rechazado:
        return AppColors.errorDark;
      case MaterialReceiptStatus.pendiente:
        return AppColors.accentDark;
    }
  }

  Color get _statusBg {
    switch (comprobante.status) {
      case MaterialReceiptStatus.aprobado:
        return AppColors.secondaryLight;
      case MaterialReceiptStatus.rechazado:
        return AppColors.errorLight;
      case MaterialReceiptStatus.pendiente:
        return AppColors.accentLight;
    }
  }

  String get _statusLabel {
    switch (comprobante.status) {
      case MaterialReceiptStatus.aprobado:
        return 'Aprobado';
      case MaterialReceiptStatus.rechazado:
        return 'Rechazado';
      case MaterialReceiptStatus.pendiente:
        return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const HugeIcon(
                    icon: HugeIcons.strokeRoundedFile01,
                    size: 18,
                    color: AppColors.lightTextSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comprobante.fileName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatMxn(comprobante.montoCentavos),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.lightTextSecondary,
              ),
            ),
            if (comprobante.rejectReason != null &&
                comprobante.rejectReason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        size: 14,
                        color: AppColors.errorDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        comprobante.rejectReason!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.errorDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
            const HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: 48,
                color: AppColors.lightTextTertiary),
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
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
              label: const Text('Reintentar'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
