import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/transaction.dart';

/// Fila de transacción en la lista de movimientos.
class TransactionTile extends StatelessWidget {
  final FinanceTransaction transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type.isIncome;
    final color = isIncome ? AppColors.secondary : AppColors.error;
    final bgColor = isIncome ? AppColors.secondaryLight : AppColors.errorLight;
    final sign = isIncome ? '+' : '-';
    final formatted = NumberFormat.currency(
      locale: 'es',
      symbol: '\$',
      decimalDigits: 2,
    ).format(transaction.amount);
    final dateStr = DateFormat('dd/MM/yyyy').format(transaction.date);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: context.sac.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: HugeIcon(
                  icon: _categoryIcon(transaction.category.iconIndex),
                  size: 22,
                  color: color,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Description + category + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.category.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Amount + registered by
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign$formatted',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.registeredByName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Mapea el índice de ícono de la BD a un HugeIcon.
  List<List<dynamic>> _categoryIcon(int index) {
    switch (index) {
      case 1:
        return HugeIcons.strokeRoundedShoppingCart01;
      case 2:
        return HugeIcons.strokeRoundedHome01;
      case 3:
        return HugeIcons.strokeRoundedCar01;
      case 4:
        return HugeIcons.strokeRoundedFavourite;
      case 5:
        return HugeIcons.strokeRoundedHeartAdd;
      case 6:
        return HugeIcons.strokeRoundedBook01;
      case 7:
        return HugeIcons.strokeRoundedGift;
      case 8:
        return HugeIcons.strokeRoundedMoneyReceive01;
      case 9:
        return HugeIcons.strokeRoundedBriefcase01;
      case 10:
        return HugeIcons.strokeRoundedTag01;
      default:
        return HugeIcons.strokeRoundedMoney01;
    }
  }
}
