import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/certificate_import_item.dart';

class CertificateImportProofCard extends StatelessWidget {
  const CertificateImportProofCard({super.key, required this.item});

  final CertificateImportItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final title = item.detectedName ?? 'Registro sin nombre';
    final date = item.completedAt ?? item.detectedDate;

    return SacCard(
      accentColor:
          item.type == CertificateImportItemType.honor ? c.warning : c.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SacBadge.success(label: 'Registro importado'),
              const Spacer(),
              SacBadge(
                label: item.type == CertificateImportItemType.honor
                    ? 'HONOR'
                    : 'CLASE',
                variant: SacBadgeVariant.neutral,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            date == null
                ? 'Fecha pendiente'
                : DateFormat('dd/MM/yyyy').format(date),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textSecondary,
                ),
          ),
          if (item.appliedEntityType != null ||
              item.appliedEntityId != null) ...[
            const SizedBox(height: 10),
            Text(
              'Aplicado en ${item.appliedEntityType ?? 'SACDIA'} #${item.appliedEntityId ?? '-'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textTertiary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
