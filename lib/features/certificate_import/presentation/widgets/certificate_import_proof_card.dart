import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/certificate_import_item.dart';
import '../providers/certificate_import_providers.dart';

class CertificateImportProofArgs {
  const CertificateImportProofArgs({
    this.item,
    this.batchId,
    this.fileId,
  });

  final CertificateImportItem? item;
  final String? batchId;
  final String? fileId;
}

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
                'id': '${item.appliedEntityId ?? '-'}',
              }),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textTertiary,
                  ),
            ),
          ],
          if (item.type == CertificateImportItemType.clazz) ...[
            if (item.isInstitutionalClass) ...[
              const SizedBox(height: 10),
              Text(
                'certificate_import.item.institutional'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: c.textTertiary,
                    ),
              ),
            ] else if (item.isGuiaMayorBase) ...[
              const SizedBox(height: 10),
              Text(
                (item.status == CertificateImportItemStatus.approved
                        ? 'certificate_import.proof.gm01_replaced'
                        : 'certificate_import.item.gm01_replace')
                    .tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: c.textTertiary,
                    ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class CertificateImportSignedProof extends ConsumerStatefulWidget {
  const CertificateImportSignedProof({
    super.key,
    required this.batchId,
    required this.fileId,
  });

  final String batchId;
  final String fileId;

  @override
  ConsumerState<CertificateImportSignedProof> createState() =>
      _CertificateImportSignedProofState();
}

class _CertificateImportSignedProofState
    extends ConsumerState<CertificateImportSignedProof> {
  String? _error;

  Future<void> _open() async {
    final result = await ref.read(signedCertificateImportDownloadProvider).call(
          batchId: widget.batchId,
          fileId: widget.fileId,
        );
    if (!mounted) return;
    await result.fold(
      (failure) async {
        setState(() => _error = failure.message);
      },
      (url) async {
        final uri = Uri.tryParse(url);
        if (uri == null || uri.scheme != 'https') {
          setState(
            () => _error = 'certificate_import.proof.unavailable'.tr(),
          );
          return;
        }
        final opened =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!opened && mounted) {
          setState(
            () => _error = 'certificate_import.proof.unavailable'.tr(),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SacPressable(
          listenOnly: true,
          child: TextButton(
            style: const ButtonStyle(enableFeedback: false),
            onPressed: _open,
            child: Text('certificate_import.proof.open'.tr()),
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.error,
                ),
          ),
      ],
    );
  }
}
