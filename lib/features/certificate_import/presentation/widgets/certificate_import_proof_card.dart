import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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
    final title = item.detectedName ?? 'certificate_import.proof.unnamed'.tr();
    final date = item.completedAt ?? item.detectedDate;

    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SacBadge.success(
                  label: 'certificate_import.proof.imported_badge'.tr()),
              const Spacer(),
              SacBadge(
                label: item.type == CertificateImportItemType.honor
                    ? 'certificate_import.item.honor'.tr()
                    : 'certificate_import.item.class'.tr(),
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
                ? 'certificate_import.proof.date_pending'.tr()
                : DateFormat('dd/MM/yyyy').format(date),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textSecondary,
                ),
          ),
          if (item.appliedEntityType != null ||
              item.appliedEntityId != null) ...[
            const SizedBox(height: 10),
            Text(
              'certificate_import.proof.applied'.tr(namedArgs: {
                'type': item.appliedEntityType ?? 'SACDIA',
                'id': '${item.appliedEntityId ?? '-'}',
              }),
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
