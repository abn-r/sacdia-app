import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/certificate_import_item.dart';

class CertificateImportItemCard extends StatelessWidget {
  const CertificateImportItemCard({
    super.key,
    required this.item,
    this.onEdit,
    this.onResubmit,
  });

  final CertificateImportItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onResubmit;

  bool get _isComplete {
    final hasCatalog = item.type == CertificateImportItemType.honor
        ? item.honorId != null
        : item.classId != null;
    return item.type != CertificateImportItemType.unknown &&
        (item.detectedName?.trim().isNotEmpty ?? false) &&
        item.completedAt != null &&
        hasCatalog;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isHonor = item.type == CertificateImportItemType.honor;
    final confidence = item.ocrConfidence == null
        ? null
        : '${(item.ocrConfidence! * 100).round()}% OCR';
    final isRejected = item.isRejected || item.rejectionReason != null;
    final statusLabel = isRejected
        ? 'RECHAZADO'
        : _isComplete
            ? 'LISTO'
            : 'FALTA DATO';

    return SacCard(
      accentColor: isHonor ? c.warning : c.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SacBadge(
                label: isHonor ? 'HONOR' : 'CLASE',
                variant:
                    isHonor ? SacBadgeVariant.accent : SacBadgeVariant.primary,
              ),
              const SizedBox(width: 8),
              SacBadge(
                label: statusLabel,
                variant: isRejected
                    ? SacBadgeVariant.error
                    : _isComplete
                        ? SacBadgeVariant.secondary
                        : SacBadgeVariant.accent,
              ),
              const Spacer(),
              if (confidence != null)
                Text(
                  confidence,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textTertiary,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.detectedName ?? 'Sin nombre detectado',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            _subtitle(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textSecondary,
                ),
          ),
          if (item.rejectionReason != null) ...[
            const SizedBox(height: 10),
            Text(
              item.rejectionReason!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          if (onResubmit != null && isRejected)
            SacButton.outline(
              text: 'Corregir y reenviar',
              onPressed: onResubmit,
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: SacButton.ghost(
                text: 'Corregir',
                onPressed: onEdit,
              ),
            ),
        ],
      ),
    );
  }

  String _subtitle() {
    final date = item.completedAt ?? item.detectedDate;
    final formattedDate = date == null
        ? 'fecha pendiente'
        : DateFormat('dd/MM/yyyy').format(date);
    final catalogId = item.type == CertificateImportItemType.honor
        ? item.honorId
        : item.classId;
    return 'Catálogo: ${catalogId ?? 'pendiente'} · $formattedDate';
  }
}
