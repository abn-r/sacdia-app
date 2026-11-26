import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';

/// Payment proof as a tappable card: the image as a thumbnail (a file tile for
/// a PDF or when the image does not load) with a «Ver comprobante» badge.
/// Opening it is the caller's job (the viewer decides how, without caching).
///
/// The thumbnail goes through `Image.network` on purpose: it only lives in the
/// in-memory image cache, never on disk (a voucher is someone's payment
/// proof).
class SupervisionVoucherCard extends StatelessWidget {
  const SupervisionVoucherCard({
    super.key,
    required this.url,
    required this.onTap,
  });

  final String url;
  final VoidCallback onTap;

  static bool isPdf(String url) =>
      (Uri.tryParse(url)?.path.toLowerCase() ?? '').endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final label = 'supervision.union_camporees.view_voucher'.tr();
    final fileTile = _FileTile(isPdf: isPdf(url));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: c.surfaceVariant,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            side: BorderSide(color: c.border),
          ),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isPdf(url))
                    fileTile
                  else
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      cacheWidth: 800,
                      errorBuilder: (_, __, ___) => fileTile,
                    ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: _Badge(label: label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.isPdf});

  final bool isPdf;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: HugeIcon(
        icon: isPdf
            ? HugeIcons.strokeRoundedFile01
            : HugeIcons.strokeRoundedInvoice01,
        size: 40,
        color: context.sac.textTertiary,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.text.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedLinkSquare02,
            size: 14,
            color: c.background,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              fontWeight: FontWeight.w600,
              color: c.background,
            ),
          ),
        ],
      ),
    );
  }
}
