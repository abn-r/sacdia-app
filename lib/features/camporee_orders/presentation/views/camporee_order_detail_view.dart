import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/providers/camporee_orders_providers.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/views/camporee_order_catalog_view.dart';
import 'package:sacdia_app/features/payment_orders/presentation/widgets/payment_order_widgets.dart';

const _proofAllowedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];
const _proofMaxSizeBytes = 10 * 1024 * 1024;

/// Detalle de un folio: PDF, comprobante, cancelación y entrega nominada.
class CamporeeOrderDetailView extends ConsumerWidget {
  final String orderId;

  const CamporeeOrderDetailView({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(camporeeOrderDetailProvider(orderId));
    final actionsState = ref.watch(camporeeOrderActionsProvider);
    final canDistributeAsync = ref.watch(canDistributeCamporeeOrdersProvider);
    final c = context.sac;

    ref.listen(camporeeOrderActionsProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null && message != previous?.errorMessage) {
        _showSnack(context, message, AppColors.error);
      }
    });

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        title: Text('camporee_orders.detail.title'.tr()),
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: orderAsync.when(
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    size: 42,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    camporeeOrdersErrorMessage(error),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  SacButton.outline(
                    text: 'common.retry'.tr(),
                    onPressed: () =>
                        ref.invalidate(camporeeOrderDetailProvider(orderId)),
                  ),
                ],
              ),
            ),
          ),
          data: (order) => _OrderDetailBody(
            order: order,
            isWorking: actionsState.isWorking,
            canDistribute:
                canDistributeAsync.valueOrNull == true && order.canDistribute,
            onViewPdf: () => _viewPdf(context, ref, order),
            onUploadProof: () => _pickAndUploadProof(context, ref),
            onCancel: () => _confirmCancel(context, ref),
            onDeliver: (lineId) => ref
                .read(camporeeOrderActionsProvider.notifier)
                .deliverLineToMember(orderId: orderId, lineId: lineId),
          ),
        ),
      ),
    );
  }

  Future<void> _viewPdf(
    BuildContext context,
    WidgetRef ref,
    CamporeeOrder order,
  ) async {
    final path = await ref
        .read(camporeeOrderActionsProvider.notifier)
        .downloadPdf(orderId);
    if (path != null && context.mounted) {
      SacPdfViewer.show(
        context,
        pdfSource: path,
        title: order.folioReference,
      );
    }
  }

  Future<void> _pickAndUploadProof(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _proofAllowedExtensions,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final path = picked.path;
    if (path == null) return;

    if (picked.size > _proofMaxSizeBytes) {
      if (context.mounted) {
        _showSnack(
          context,
          'camporee_orders.detail.proof_too_large'.tr(),
          AppColors.error,
        );
      }
      return;
    }

    final file = File(path);
    if (!await file.exists()) return;

    final uploaded =
        await ref.read(camporeeOrderActionsProvider.notifier).uploadProof(
              orderId: orderId,
              filePath: path,
              fileName: picked.name,
              mimeType: _mimeFromExtension(picked.extension),
            );

    if (uploaded && context.mounted) {
      _showSnack(
        context,
        'camporee_orders.detail.proof_uploaded'.tr(),
        AppColors.secondary,
      );
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'camporee_orders.detail.cancel_title'.tr(),
      content: 'camporee_orders.detail.cancel_body'.tr(),
      confirmLabel: 'camporee_orders.detail.cancel_confirm'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true) return;

    final cancelled = await ref
        .read(camporeeOrderActionsProvider.notifier)
        .cancelOrder(orderId);
    if (cancelled && context.mounted) {
      _showSnack(
        context,
        'camporee_orders.detail.cancelled'.tr(),
        AppColors.secondary,
      );
    }
  }

  void _showSnack(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _mimeFromExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}

class _OrderDetailBody extends StatelessWidget {
  final CamporeeOrder order;
  final bool isWorking;
  final bool canDistribute;
  final VoidCallback onViewPdf;
  final VoidCallback onUploadProof;
  final VoidCallback onCancel;
  final Future<bool> Function(String lineId) onDeliver;

  const _OrderDetailBody({
    required this.order,
    required this.isWorking,
    required this.canDistribute,
    required this.onViewPdf,
    required this.onUploadProof,
    required this.onCancel,
    required this.onDeliver,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateFormat = DateFormat.yMMMd(context.locale.toString());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.folioReference,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                    ),
                    CamporeeOrderStatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'camporee_orders.detail.total'.tr(),
                  value: formatCentavos(order.totalCentavos, order.currency),
                  emphasized: true,
                ),
                _DetailRow(
                  label: 'camporee_orders.detail.expires'.tr(),
                  value: dateFormat.format(order.expiresAt.toLocal()),
                ),
                _DetailRow(
                  label: 'camporee_orders.detail.distribution'.tr(),
                  value:
                      camporeeOrderDistributionLabel(order.distributionStatus),
                ),
              ],
            ),
          ),
          if (order.summary.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'camporee_orders.review.summary_title'.tr(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 10),
            for (final item in order.summary)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  item.optionLabelSnapshot == null
                      ? '${item.productTitleSnapshot} × ${item.qty}'
                      : '${item.productTitleSnapshot} (${item.optionLabelSnapshot}) × ${item.qty}',
                  style: TextStyle(fontSize: 13.5, color: c.text),
                ),
              ),
          ],
          if (order.lines.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'camporee_orders.review.named_title'.tr(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 10),
            for (final line in order.lines)
              _NamedDeliverRow(
                line: line,
                canDistribute: canDistribute && !line.deliveredToMember,
                isWorking: isWorking,
                onDeliver: () => onDeliver(line.lineId),
              ),
          ],
          const SizedBox(height: 18),
          SacButton.outline(
            text: 'camporee_orders.detail.view_pdf'.tr(),
            icon: HugeIcons.strokeRoundedPdf01,
            onPressed: isWorking ? null : onViewPdf,
          ),
          if (order.canUploadProof) ...[
            const SizedBox(height: 12),
            SacButton.primary(
              text: order.status == CamporeeOrderStatus.proofRejected
                  ? 'camporee_orders.detail.reupload_proof'.tr()
                  : 'camporee_orders.detail.upload_proof'.tr(),
              icon: HugeIcons.strokeRoundedUpload01,
              isLoading: isWorking,
              onPressed: isWorking ? null : onUploadProof,
            ),
          ],
          if (order.canCancel) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: isWorking ? null : onCancel,
              child: Text(
                'camporee_orders.detail.cancel_order'.tr(),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NamedDeliverRow extends StatelessWidget {
  final CamporeeOrderLine line;
  final bool canDistribute;
  final bool isWorking;
  final VoidCallback onDeliver;

  const _NamedDeliverRow({
    required this.line,
    required this.canDistribute,
    required this.isWorking,
    required this.onDeliver,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final option = line.optionLabelSnapshot == null
        ? ''
        : ' · ${line.optionLabelSnapshot}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${line.beneficiaryNameSnapshot} — ${line.productTitleSnapshot}$option × ${line.qty}',
            style: TextStyle(fontSize: 13, color: c.text),
          ),
          if (line.deliveredToMember) ...[
            const SizedBox(height: 6),
            Text(
              'camporee_orders.detail.delivered_to_member'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
          ],
          if (canDistribute) ...[
            const SizedBox(height: 8),
            SacButton.outline(
              key: Key('camporee-order-deliver-${line.lineId}'),
              text: 'camporee_orders.detail.deliver'.tr(),
              isEnabled: !isWorking,
              onPressed: isWorking ? null : onDeliver,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: emphasized ? 15 : 13,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
                color: c.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
