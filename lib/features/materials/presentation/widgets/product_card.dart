import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/material_item.dart';
import '../utils/money_format.dart';

/// Tarjeta de producto del catálogo (grid 2 columnas).
class ProductCard extends StatelessWidget {
  final MaterialItem item;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasStock = item.stock > 0;

    return SacPressable(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: item.title,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border.withValues(alpha: 0.75)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: AppColors.primary.withValues(alpha: 0.08),
                  alignment: Alignment.center,
                  child: HugeIcon(
                    icon: _categoryIcon(item.category.slug),
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatMxn(item.priceCentavos),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _stockLabel(hasStock: hasStock, stock: item.stock),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasStock
                            ? (item.stock <= 5
                                ? AppColors.warning
                                : c.textTertiary)
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<List<dynamic>> _categoryIcon(String slug) {
    switch (slug.toLowerCase()) {
      case 'insignias':
        return HugeIcons.strokeRoundedAward01;
      case 'uniforme':
      case 'uniformes':
        return HugeIcons.strokeRoundedShirt01;
      case 'panoletas':
      case 'pañoletas':
        return HugeIcons.strokeRoundedTie;
      case 'material':
      case 'materiales':
        return HugeIcons.strokeRoundedPackage;
      case 'cuadernillos':
      case 'libros':
        return HugeIcons.strokeRoundedBook02;
      default:
        return HugeIcons.strokeRoundedShoppingBag01;
    }
  }

  static String _stockLabel({required bool hasStock, required int stock}) {
    if (!hasStock) return 'materials.catalog.out_of_stock'.tr();
    if (stock <= 5) return 'materials.catalog.low_stock'.tr();
    return 'materials.catalog.in_stock'.tr();
  }
}
