import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/finance_month.dart';
import '../providers/finanzas_providers.dart';

/// Tarjeta principal con saldo acumulado + navegación de mes.
///
/// Sigue el design system "Scout Vibrante":
/// fondo de surface con borde sutil, icono en contenedor de acento,
/// sin gradientes, tokens de color semánticos via `context.sac`.
class BalanceHeaderCard extends ConsumerWidget {
  final FinanceMonth? financeMonth;
  final double? totalBalance;

  const BalanceHeaderCard({
    super.key,
    required this.financeMonth,
    this.totalBalance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final selected = ref.watch(selectedMonthProvider);
    final canGoNext = !selected.isCurrentMonth;
    final monthLabel = _monthLabel(selected.year, selected.month);
    final balance = totalBalance ?? financeMonth?.totalBalance ?? 0;
    final isOpen = financeMonth?.isOpen ?? true;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: c.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row: icon + label + period badge
          Row(
            children: [
              // Icon container — standard app pattern
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedWallet01,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Label
              Text(
                'Saldo del Club',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w600,
                    ),
              ),

              const Spacer(),

              // Open / closed status badge
              _PeriodBadge(isOpen: isOpen),
            ],
          ),

          const SizedBox(height: 14),

          // Balance amount
          Text(
            _formatCurrency(balance),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: c.text,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),

          // Month navigator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NavButton(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                onTap: () =>
                    ref.read(selectedMonthProvider.notifier).goToPrevious(),
              ),
              const SizedBox(width: 12),
              Text(
                monthLabel,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 12),
              _NavButton(
                icon: HugeIcons.strokeRoundedArrowRight01,
                onTap: canGoNext
                    ? () =>
                        ref.read(selectedMonthProvider.notifier).goToNext()
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    final formatter = NumberFormat.currency(
      locale: 'es',
      symbol: '\$',
      decimalDigits: 2,
    );
    return formatter.format(value);
  }

  String _monthLabel(int year, int month) {
    final date = DateTime(year, month);
    final label = DateFormat('MMMM yyyy', 'es').format(date);
    return label[0].toUpperCase() + label.substring(1);
  }
}

class _PeriodBadge extends StatelessWidget {
  final bool isOpen;

  const _PeriodBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final badgeColor = isOpen ? AppColors.secondary : AppColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: isOpen
                ? HugeIcons.strokeRoundedLock
                : HugeIcons.strokeRoundedLocked,
            size: 11,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            isOpen ? 'Abierto' : 'Cerrado',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final List<List<dynamic>> icon;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final disabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: disabled ? c.borderLight : c.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusXS),
          border: Border.all(color: c.border),
        ),
        child: Center(
          child: HugeIcon(
            icon: icon,
            size: 18,
            color: disabled ? c.textTertiary : c.text,
          ),
        ),
      ),
    );
  }
}
