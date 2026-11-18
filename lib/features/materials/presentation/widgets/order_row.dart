import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../domain/entities/order.dart';
import '../utils/order_presentation.dart';
import 'material_thumbs.dart';

/// One order of the list: its products stacked, the state (icon and color
/// say it, the text says it too), the folio whole and the amount.
class OrderRow extends StatelessWidget {
  const OrderRow({super.key, required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  /// Left inset of the dividers of a group of these rows.
  static const double dividerIndent = 14 + _thumbsWidth + 12;
  static const double _thumbsWidth = 52;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = orderRowStyle(context, order);
    final folio = order.folioReferencia?.trim() ?? '';
    final hasFolio = folio.isNotEmpty;
    final total = SacMoney.fromCentavos(order.totalCentavos);
    // "Pagar $410.00" already says the amount.
    final showAmount = orderAttention(order) != OrderAttention.pay;
    final folioText = hasFolio ? folio : 'materials.history.no_folio'.tr();

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: [style.label, folioText, if (showAmount) total].join('. '),
      onTap: onTap,
      child: SacInkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(
              children: [
                SizedBox(
                  width: _thumbsWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ThumbStack(
                      categorySlugs: List<String?>.filled(
                        order.lines.length.clamp(1, 2),
                        null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          buildIcon(style.icon, size: 16, color: style.color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              style.label,
                              style: TextStyle(
                                fontSize: SacFontSize.titleMedium,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                                color: style.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // The folio is an identifier: never cut, never formatted.
                      Text(
                        folioText,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          height: 1.35,
                          fontFamily: hasFolio ? 'monospace' : null,
                          color: hasFolio ? c.textSecondary : c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showAmount) ...[
                  const SizedBox(width: 8),
                  Text(
                    total,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                      fontFeatures: SacMoney.tabularFigures,
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                ExcludeSemantics(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
