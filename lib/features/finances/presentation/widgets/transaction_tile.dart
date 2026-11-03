import 'package:flutter/material.dart';
import '../theme/finance_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_profile_image.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../domain/entities/transaction.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Fila de transacción con ícono de categoría, descripción y monto.
class TransactionTile extends StatelessWidget {
  final FinanceTransaction transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  static const _iconMap = <int, HugeIconData>{
    1: HugeIcons.strokeRoundedShoppingCart01,
    2: HugeIcons.strokeRoundedHome01,
    3: HugeIcons.strokeRoundedCar01,
    4: HugeIcons.strokeRoundedStar,
    5: HugeIcons.strokeRoundedFavourite,
    6: HugeIcons.strokeRoundedBookOpen01,
    7: HugeIcons.strokeRoundedGift,
    8: HugeIcons.strokeRoundedMoney01,
    9: HugeIcons.strokeRoundedBriefcaseDollar,
    10: HugeIcons.strokeRoundedTag01,
  };

  static const HugeIconData _defaultIcon = HugeIcons.strokeRoundedMoney01;
  static final _currencyFormatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 2,
  );
  static final _timeFormatter = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = transaction.type.isIncome;
    final category = transaction.category;
    final accentColor = FinanceTokens.categoryAccents[category.iconIndex] ??
        FinanceTokens.defaultCategoryAccent;
    final icon = _iconFor(category.name, category.iconIndex);

    final transactionSurface = isDark ? context.sac.surface : context.sac.ink50;

    final amountColor = isIncome
        ? (isDark ? context.sac.success : AppColors.secondaryDark)
        : context.sac.error;

    final formatted = _currencyFormatter.format(transaction.amount);

    final sign = isIncome ? '+' : '-';
    final timeStr = _timeFormatter.format(transaction.registeredAt.toLocal());

    return SacInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: transactionSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: isDark
              ? null
              : Border.all(
                  color: context.sac.ink100,
                  width: 1,
                ),
        ),
        child: Row(
          children: [
            // Category icon in a small rounded square (no chip with text)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(AppTheme.radiusXS),
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  size: 20,
                  color: accentColor,
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
                      fontSize: SacFontSize.bodyMedium,
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
                      fontSize: SacFontSize.labelSmall,
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
                    fontSize: SacFontSize.titleMedium,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$timeStr · MXN',
                  style: TextStyle(
                    fontSize: SacFontSize.caption,
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
                          ? sacProfileImageProvider(
                              transaction.registeredByPhoto!)
                          : null,
                      onBackgroundImageError:
                          transaction.registeredByPhoto != null
                              ? (_, __) {}
                              : null,
                      child: transaction.registeredByPhoto == null
                          ? HugeIcon(
                              icon: HugeIcons.strokeRoundedUser,
                              size: 8,
                              color: context.sac.textTertiary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      transaction.registeredByName,
                      style: TextStyle(
                        fontSize: SacFontSize.micro,
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

  static HugeIconData _iconFor(String categoryName, int iconIndex) {
    final iconByIndex = _iconMap[iconIndex];
    if (iconByIndex != null) return iconByIndex;

    final normalized = categoryName.toLowerCase();
    if (normalized.contains('venta')) {
      return HugeIcons.strokeRoundedMoneyReceive01;
    }
    if (normalized.contains('seguro') || normalized.contains('médico')) {
      return HugeIcons.strokeRoundedHealth;
    }
    if (normalized.contains('cuadern') ||
        normalized.contains('material') ||
        normalized.contains('clase')) {
      return HugeIcons.strokeRoundedBookOpen01;
    }
    if (normalized.contains('transporte')) {
      return HugeIcons.strokeRoundedCar01;
    }
    if (normalized.contains('comida')) {
      return HugeIcons.strokeRoundedShoppingBasket01;
    }
    if (normalized.contains('inscripción') ||
        normalized.contains('inscripcion')) {
      return HugeIcons.strokeRoundedInvoice03;
    }
    if (normalized.contains('apoyo')) {
      return HugeIcons.strokeRoundedGift;
    }

    return _defaultIcon;
  }
}
