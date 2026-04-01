import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/transaction.dart';

/// Fila de transacción con chip de categoría con emoji, descripción y monto.
class TransactionTile extends StatelessWidget {
  final FinanceTransaction transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  static const _emojiMap = {
    1: '🛒',
    2: '🏠',
    3: '🚗',
    4: '⭐',
    5: '❤️',
    6: '📚',
    7: '🎁',
    8: '💰',
    9: '💼',
    10: '🏷️',
  };

  static const _accentColors = {
    1: Color(0xFFF59E0B),
    2: Color(0xFF6366F1),
    3: Color(0xFF3B82F6),
    4: Color(0xFFEC4899),
    5: Color(0xFFEF4444),
    6: Color(0xFF8B5CF6),
    7: Color(0xFFF97316),
    8: Color(0xFF10B981),
    9: Color(0xFF0EA5E9),
    10: Color(0xFF64748B),
  };

  static const _defaultAccent = Color(0xFF6B7280);
  static const _defaultEmoji = '💵';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = transaction.type.isIncome;
    final category = transaction.category;
    final accentColor = _accentColors[category.iconIndex] ?? _defaultAccent;
    final emoji = _emojiMap[category.iconIndex] ?? _defaultEmoji;

    final transactionSurface =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC);

    final amountColor = isIncome
        ? (isDark ? const Color(0xFF4FBF9F) : const Color(0xFF2D8A70))
        : const Color(0xFFDC2626);

    final formatted = NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    ).format(transaction.amount);

    final sign = isIncome ? '+' : '-';
    final timeStr =
        DateFormat('hh:mm a').format(transaction.registeredAt.toLocal());

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: transactionSurface,
          borderRadius: BorderRadius.circular(16),
          border: isDark
              ? null
              : Border.all(
                  color: const Color(0xFFF1F5F9),
                  width: 1,
                ),
        ),
        child: Row(
          children: [
            // Emoji icon in a small rounded square (no chip with text)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Description (concept) on top, category name below
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.sac.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: context.sac.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Amount + time + registeredBy on the right
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign$formatted',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$timeStr · MXN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: context.sac.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 6,
                      backgroundColor: context.sac.surfaceVariant,
                      backgroundImage: transaction.registeredByPhoto != null
                          ? NetworkImage(transaction.registeredByPhoto!)
                          : null,
                      onBackgroundImageError:
                          transaction.registeredByPhoto != null
                              ? (_, __) {}
                              : null,
                      child: transaction.registeredByPhoto == null
                          ? Icon(
                              Icons.person,
                              size: 8,
                              color: context.sac.textTertiary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      transaction.registeredByName,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: context.sac.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

