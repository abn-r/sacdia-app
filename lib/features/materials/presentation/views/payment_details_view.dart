import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/material_status.dart';
import '../providers/order_detail_provider.dart';
import '../utils/money_format.dart';

/// Pantalla "Datos para pago" — muestra la CLABE, referencia bancaria y
/// total a pagar una vez que la orden fue aprobada.
///
/// El director usa esta información para realizar su transferencia antes de
/// subir el comprobante.
class PaymentDetailsView extends ConsumerWidget {
  final String folioOrId;

  const PaymentDetailsView({super.key, required this.folioOrId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordenAsync = ref.watch(orderDetailProvider(folioOrId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Datos para pago'),
      ),
      body: ordenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: e.toString(),
          onRetry: () => ref.invalidate(orderDetailProvider(folioOrId)),
        ),
        data: (orden) {
          if (orden.status != MaterialStatus.aprobada) {
            return _NotRequiredBody(
              onBack: () => context.pop(),
            );
          }
          return _PagoBody(orden: orden, folioOrId: folioOrId);
        },
      ),
    );
  }
}

// ── Body cuando la orden está aprobada ────────────────────────────────────────

class _PagoBody extends StatelessWidget {
  final dynamic orden; // Orden entity
  final String folioOrId;

  const _PagoBody({required this.orden, required this.folioOrId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Referencia bancaria ───────────────────────────────────────────────
        if (orden.folioReferencia != null) ...[
          _SectionLabel(label: 'Referencia bancaria'),
          const SizedBox(height: 8),
          _CopyCard(
            label: 'Referencia',
            value: orden.folioReferencia!,
            mono: true,
          ),
          const SizedBox(height: 20),
        ],

        // ── Datos de la cuenta ────────────────────────────────────────────────
        _SectionLabel(label: 'Datos de la cuenta'),
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
                if (orden.bankName != null && orden.bankName!.isNotEmpty)
                  _DataRow(label: 'Banco', value: orden.bankName!),
                if (orden.accountHolder != null &&
                    orden.accountHolder!.isNotEmpty)
                  _DataRow(label: 'Titular', value: orden.accountHolder!),
                if (orden.bankAccountClabe != null &&
                    orden.bankAccountClabe!.isNotEmpty)
                  _DataRow(
                    label: 'CLABE',
                    value: orden.bankAccountClabe!,
                    mono: true,
                    copyable: true,
                  ),
                _DataRow(
                  label: 'Monto a pagar',
                  value: formatMxn(orden.totalCentavos),
                  bold: true,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ── Nota instructiva ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.statusInfoBgLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppColors.statusInfoText.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HugeIcon(
                  icon: HugeIcons.strokeRoundedInformationCircle,
                  size: 16,
                  color: AppColors.statusInfoText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Realizá la transferencia a la CLABE de arriba. '
                  'Usá la referencia como concepto de pago para que el '
                  'campo local identifique tu depósito.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.statusInfoText,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // ── CTA ───────────────────────────────────────────────────────────────
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedFileUpload),
          label: const Text('Ya pagué, subir comprobante'),
          onPressed: () =>
              context.push(RouteNames.materialsOrderReceipt(folioOrId)),
        ),
      ],
    );
  }
}

// ── Error state cuando el estado no requiere pago ─────────────────────────────

class _NotRequiredBody extends StatelessWidget {
  final VoidCallback onBack;
  const _NotRequiredBody({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
                icon: HugeIcons.strokeRoundedCancel02,
                size: 48,
                color: AppColors.lightTextTertiary),
            const SizedBox(height: 12),
            Text(
              'Esta orden no requiere pago',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'El estado actual de la orden no admite subir comprobante.',
              style: const TextStyle(color: AppColors.lightTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01),
              label: const Text('Volver'),
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error genérico ─────────────────────────────────────────────────────────────

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

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.lightText,
          ),
    );
  }
}

/// Card con un valor copiable y fuente monoespaciada para CLABE / folio.
class _CopyCard extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _CopyCard({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.lightTextSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: mono ? 'monospace' : null,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: mono ? 1.2 : null,
                      color: AppColors.lightText,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedCopy01),
              tooltip: 'Copiar',
              color: AppColors.primary,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copiada')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final bool copyable;
  final bool bold;

  const _DataRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.copyable = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: mono ? 'monospace' : null,
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold ? AppColors.primary : AppColors.lightText,
                letterSpacing: mono ? 0.8 : null,
              ),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copiada')),
                );
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCopy01,
                    size: 16,
                    color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}
