import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../domain/entities/certificate_import_payloads.dart';
import '../../domain/entities/certificate_import_batch.dart';
import '../../domain/entities/certificate_import_item.dart';
import '../../domain/usecases/resubmit_certificate_import_item.dart';
import '../error/certificate_import_error_mapper.dart';
import '../providers/certificate_import_providers.dart';
import '../widgets/certificate_import_back_button.dart';
import '../widgets/certificate_import_item_card.dart';
import '../widgets/import_load_error_scaffold.dart';

class CertificateImportStatusRouteView extends ConsumerWidget {
  const CertificateImportStatusRouteView({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchAsync = ref.watch(certificateImportBatchProvider(batchId));
    return batchAsync.when(
      loading: () => const Scaffold(body: Center(child: SacLoading())),
      error: (_, __) => ImportLoadErrorScaffold(
        title: 'certificate_import.status.title'.tr(),
        bodyKey: 'certificate_import.status.load_error',
        fallbackLocation: RouteNames.certificateImportUpload,
        onRetry: () => ref.invalidate(certificateImportBatchProvider(batchId)),
      ),
      data: (batch) => CertificateImportStatusView(
        batch: batch,
        onResubmitItem: (item) async {
          final result =
              await ref.read(resubmitCertificateImportItemProvider).call(
                    ResubmitCertificateImportItemParams(
                      batchId: batch.id,
                      itemId: item.id,
                      payload: CertificateImportItemUpdatePayload(
                        itemType: item.type == CertificateImportItemType.honor
                            ? 'HONOR'
                            : 'CLASS',
                        honorId: item.honorId,
                        classId: item.classId,
                        detectedName: item.detectedName,
                        completedAt: _apiDate(item.completedAt),
                        markAsReady: true,
                      ),
                    ),
                  );
          result.fold((failure) => throw failure, (_) {});
        },
      ),
    );
  }

  static String? _apiDate(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class CertificateImportStatusView extends StatelessWidget {
  const CertificateImportStatusView({
    super.key,
    required this.batch,
    this.onResubmitItem,
  });

  final CertificateImportBatch batch;
  final Future<void> Function(CertificateImportItem item)? onResubmitItem;

  Future<void> _resubmit(
    BuildContext context,
    CertificateImportItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await onResubmitItem?.call(item);
    } catch (error) {
      SacSnackBar.showMessenger(
        messenger,
        CertificateImportErrorMapper.message(error),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final items = batch.activeItems;
    final rejected = items
        .where((item) => item.isRejected || item.rejectionReason != null)
        .toList();
    final approved = items
        .where((item) => item.status == CertificateImportItemStatus.approved)
        .length;
    // Every other row the member kept is still waiting for a decision. A row
    // that was just sent (`submitted`) counts too: before, only rows that
    // were not sent yet did, so a fully sent batch read "Pendientes: 0".
    final pending = items
        .where((item) =>
            item.status != CertificateImportItemStatus.approved &&
            !rejected.contains(item))
        .length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'certificate_import.status.title'.tr(),
          leading: CertificateImportBackButton(
            fallbackLocation: RouteNames.certificateImportReviewPath(batch.id),
          ),
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => ListView(
            padding: SacTopBar.paddingBelowBar(
                context, const EdgeInsets.fromLTRB(16, 8, 16, 28)),
            children: [
              SacCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SacBadge(
                      label: rejected.isNotEmpty
                          ? 'certificate_import.status.corrections_title'.tr()
                          : 'certificate_import.status.in_review_title'.tr(),
                      variant: rejected.isNotEmpty
                          ? SacBadgeVariant.error
                          : SacBadgeVariant.accent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      rejected.isNotEmpty
                          ? 'certificate_import.status.corrections_body'.tr()
                          : 'certificate_import.status.in_review_body'.tr(),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: c.text,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'certificate_import.status.counts'.tr(namedArgs: {
                        'approved': '$approved',
                        'rejected': '${rejected.length}',
                        'pending': '$pending',
                      }),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: c.textSecondary,
                          ),
                    ),
                    if (items.any((item) => item.isGuiaMayorBase)) ...[
                      const SizedBox(height: 10),
                      Text(
                        'certificate_import.status.gm01_replace'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: c.textSecondary,
                            ),
                      ),
                    ],
                    if (items.any((item) => item.isInstitutionalClass)) ...[
                      const SizedBox(height: 10),
                      Text(
                        'certificate_import.status.institutional'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: c.textSecondary,
                            ),
                      ),
                    ],
                    if (items
                        .any((item) => item.isPendingAdministrativePeriod)) ...[
                      const SizedBox(height: 10),
                      Text(
                        'certificate_import.status.period_pending'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: c.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (final item in rejected) ...[
                CertificateImportItemCard(
                  item: item,
                  onResubmit: () => _resubmit(context, item),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
