import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/members/presentation/providers/members_providers.dart';
import '../../domain/entities/material_delivery.dart';
import '../providers/cart_provider.dart';
import '../providers/config_provider.dart';
import '../providers/create_order_provider.dart';
import '../utils/money_format.dart';

/// Pantalla de resumen y confirmación de pedido.
///
/// Muestra los datos de entrega, el listado de líneas del carrito (solo
/// lectura), notas opcionales y el footer con totales + CTA de confirmación.
class OrderSummaryView extends ConsumerStatefulWidget {
  const OrderSummaryView({super.key});

  @override
  ConsumerState<OrderSummaryView> createState() => _OrderSummaryViewState();
}

class _OrderSummaryViewState extends ConsumerState<OrderSummaryView> {
  MaterialDelivery _entrega = MaterialDelivery.recoger;
  final _notasController = TextEditingController();

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    // Redirect to catalog if cart is empty (e.g. after a back navigation).
    if (cart.lines.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(RouteNames.homeMaterials);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final configAsync = ref.watch(configProvider);
    final createState = ref.watch(createOrderProvider);
    final theme = Theme.of(context);

    final envioCentavos = _entrega == MaterialDelivery.envio
        ? (configAsync.valueOrNull?.envioCentavosDefault ?? 0)
        : 0;
    final total = cart.subtotalCentavos + envioCentavos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar pedido'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          // ── Subtitle ─────────────────────────────────────────────────────
          Text(
            'Revisá los datos antes de confirmar tu pedido.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // ── Datos de entrega ──────────────────────────────────────────────
          _SectionHeader(title: 'Datos de entrega'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.lightBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modalidad',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.lightBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<MaterialDelivery>(
                      value: _entrega,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: MaterialDelivery.recoger,
                          child: Text('Recoger en campo'),
                        ),
                        DropdownMenuItem(
                          value: MaterialDelivery.envio,
                          child: Text('Envío a domicilio'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _entrega = v);
                      },
                    ),
                  ),
                  if (_entrega == MaterialDelivery.envio) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedInformationCircle,
                            size: 16,
                            color: AppColors.accentDark,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'El campo local coordinará los datos de envío tras aprobar el pedido.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.accentDark,
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
          ),
          const SizedBox(height: 24),

          // ── Resumen del pedido ────────────────────────────────────────────
          _SectionHeader(title: 'Resumen del pedido'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.lightBorder),
            ),
            child: Column(
              children: [
                for (int i = 0; i < cart.lines.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _ResumenLineItem(line: cart.lines[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Notas opcionales ──────────────────────────────────────────────
          _SectionHeader(title: 'Notas (opcional)'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notasController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Instrucciones especiales, observaciones…',
              hintStyle: TextStyle(color: AppColors.lightTextTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.lightBorder),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),

      // ── Footer fijo con totales + CTA ─────────────────────────────────────
      bottomSheet: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: const Border(
            top: BorderSide(color: AppColors.lightBorder),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TotalRow(
              label: 'Subtotal',
              amount: cart.subtotalCentavos,
              isTotal: false,
            ),
            const SizedBox(height: 4),
            _TotalRow(
              label: 'Costo de envío',
              amount: envioCentavos,
              isTotal: false,
            ),
            const Divider(height: 16),
            _TotalRow(
              label: 'Total',
              amount: total,
              isTotal: true,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    createState.isLoading ? null : () => _confirm(context, ref),
                child: createState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Confirmar pedido',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    if (cart.lines.isEmpty) return;

    // Resolve club_section_id from the active club context.
    // TODO(integration): If the user has no active club context this will
    // be null. Using 0 as sentinel causes a 404 on the backend; surface a
    // proper error in that case.
    final clubCtx = await ref.read(clubContextProvider.future);
    final clubSectionId = clubCtx?.sectionId ?? 0;

    final lines = cart.lines
        .map((l) => (
              productId: l.productId,
              variantOptionId: l.variantOptionId,
              qty: l.qty,
            ))
        .toList();

    final result = await ref.read(createOrderProvider.notifier).confirm(
          clubSectionId: clubSectionId,
          lines: lines,
          delivery: _entrega,
          notas: _notasController.text.trim().isEmpty
              ? null
              : _notasController.text.trim(),
        );

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.error,
          ),
        );
      },
      (order) {
        ref.read(cartProvider.notifier).clear();
        context.go(RouteNames.materialsOrderDetail(order.id));
      },
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

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

class _ResumenLineItem extends StatelessWidget {
  final CartLine line;
  const _ResumenLineItem({required this.line});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Letter placeholder thumbnail
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              line.productTitle.isNotEmpty
                  ? line.productTitle[0].toUpperCase()
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
                  line.productTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (line.variantLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    line.variantLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${line.qty} × ${formatMxn(line.priceSnapshotCentavos)}',
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
              color: AppColors.lightText,
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
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.lightTextSecondary,
                ),
        ),
        Text(
          formatMxn(amount),
          style: isTotal
              ? theme.textTheme.titleMedium?.copyWith(
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
