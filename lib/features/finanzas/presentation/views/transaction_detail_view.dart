import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/transaction.dart';
import '../providers/finanzas_providers.dart';
import 'add_transaction_sheet.dart';

/// Vista de detalle de un movimiento financiero.
///
/// Muestra todos los campos del movimiento y ofrece el botón de edición
/// cuando el mes está abierto y el usuario tiene permisos.
class TransactionDetailView extends ConsumerWidget {
  final FinanceTransaction transaction;

  const TransactionDetailView({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = transaction.type.isIncome;
    final color = isIncome ? AppColors.secondary : AppColors.error;
    final canManageAsync = ref.watch(canManageFinancesProvider);
    final financeMonthAsync = ref.watch(financeMonthProvider);
    final isOpen = financeMonthAsync.valueOrNull?.isOpen ?? true;
    final canEdit = (canManageAsync.valueOrNull ?? false) && isOpen;

    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: AppBar(
        backgroundColor: context.sac.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Detalle del Movimiento'),
        actions: [
          if (canEdit)
            IconButton(
              onPressed: () => _openEditSheet(context),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedPencilEdit01,
                size: 20,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type + amount hero
            _AmountHero(transaction: transaction, color: color),

            const SizedBox(height: 20),

            // Details card
            _DetailCard(
              children: [
                _DetailRow(
                  icon: HugeIcons.strokeRoundedNote01,
                  label: 'Concepto',
                  value: transaction.description,
                ),
                _divider(),
                _DetailRow(
                  icon: HugeIcons.strokeRoundedTag01,
                  label: 'Categoría',
                  value: transaction.category.name,
                ),
                _divider(),
                _DetailRow(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  label: 'Fecha',
                  value: DateFormat('dd \'de\' MMMM \'de\' yyyy', 'es')
                      .format(transaction.date),
                ),
                if (transaction.notes != null &&
                    transaction.notes!.isNotEmpty) ...[
                  _divider(),
                  _DetailRow(
                    icon: HugeIcons.strokeRoundedInformationCircle,
                    label: 'Notas',
                    value: transaction.notes!,
                    multiline: true,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Audit card
            _DetailCard(
              children: [
                _DetailRow(
                  icon: HugeIcons.strokeRoundedUser,
                  label: 'Registrado por',
                  value: transaction.registeredByName,
                ),
                _divider(),
                _DetailRow(
                  icon: HugeIcons.strokeRoundedClock01,
                  label: 'Fecha de registro',
                  value: DateFormat('dd/MM/yyyy HH:mm').format(transaction.registeredAt),
                ),
                if (transaction.modifiedByName != null) ...[
                  _divider(),
                  _DetailRow(
                    icon: HugeIcons.strokeRoundedPencilEdit01,
                    label: 'Modificado por',
                    value: transaction.modifiedByName!,
                  ),
                  if (transaction.modifiedAt != null) ...[
                    _divider(),
                    _DetailRow(
                      icon: HugeIcons.strokeRoundedClock01,
                      label: 'Fecha de modificación',
                      value: DateFormat('dd/MM/yyyy HH:mm')
                          .format(transaction.modifiedAt!),
                    ),
                  ],
                ],
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(existing: transaction),
    );
  }

  Widget _divider() => const Divider(height: 1, thickness: 0.5);
}

// ── Amount hero ────────────────────────────────────────────────────────────────

class _AmountHero extends StatelessWidget {
  final FinanceTransaction transaction;
  final Color color;

  const _AmountHero({required this.transaction, required this.color});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type.isIncome;
    final formatted = NumberFormat.currency(
      locale: 'es',
      symbol: '\$',
      decimalDigits: 2,
    ).format(transaction.amount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: isIncome
                    ? HugeIcons.strokeRoundedArrowDown01
                    : HugeIcons.strokeRoundedArrowUp01,
                size: 28,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isIncome ? 'Ingreso' : 'Egreso',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatted,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail card ────────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final List<Widget> children;

  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final String value;
  final bool multiline;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          HugeIcon(
            icon: icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: multiline ? null : 2,
                  overflow: multiline ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
