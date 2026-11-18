import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';

/// Icon of a product category. Products have no photo yet, so the category
/// stands in for the image.
HugeIconData materialCategoryIcon(String? slug) {
  switch ((slug ?? '').toLowerCase()) {
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

/// Square tile for a product: the [imageUrl] when there is one, otherwise the
/// category icon on the tinted accent. Decorative: the name next to it carries
/// the meaning.
class ProductThumb extends StatelessWidget {
  const ProductThumb({
    super.key,
    this.categorySlug,
    this.size = 46,
    this.radius = AppTheme.radiusSM,
    this.ringed = false,
  });

  final String? categorySlug;
  final double size;
  final double radius;

  /// Draws a surface-colored ring so overlapping tiles stay readable.
  final bool ringed;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.surface,
          borderRadius: BorderRadius.circular(radius),
          border: ringed ? Border.all(color: c.surface, width: 2) : null,
        ),
        child: buildIcon(
          materialCategoryIcon(categorySlug),
          size: size * 0.5,
          color: accent.color,
        ),
      ),
    );
  }
}

/// Up to [maxTiles] product tiles overlapping, to recognize an order without
/// reading its folio.
class ThumbStack extends StatelessWidget {
  const ThumbStack({
    super.key,
    required this.categorySlugs,
    this.maxTiles = 2,
    this.size = 34,
  });

  final List<String?> categorySlugs;
  final int maxTiles;
  final double size;

  static const double _overlap = 16;

  @override
  Widget build(BuildContext context) {
    final slugs = categorySlugs.take(maxTiles).toList();
    if (slugs.isEmpty) slugs.add(null);
    return SizedBox(
      width: size + (slugs.length - 1) * (size - _overlap),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < slugs.length; i++)
            Positioned(
              left: i * (size - _overlap),
              child: ProductThumb(
                categorySlug: slugs[i],
                size: size,
                radius: AppTheme.radiusXS,
                ringed: true,
              ),
            ),
        ],
      ),
    );
  }
}
