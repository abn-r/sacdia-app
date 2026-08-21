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

import '../../domain/entities/payment_order.dart';
import '../providers/payment_orders_providers.dart';
import '../widgets/payment_order_widgets.dart';

const _proofAllowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
const _proofMaxSizeBytes = 10 * 1024 * 1024;

/// Detalle de una orden de pago: estado, beneficiarios, PDF y comprobante.
class PaymentOrderDetailView extends ConsumerWidget {
  final String orderId;

  const PaymentOrderDetailView({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(paymentOrderDetailProvider(orderId));
    final actionsState = ref.watch(orderActionsNotifierProvider);
    final c = context.sac;

    ref.listen(orderActionsNotifierProvider, (previous, next) {
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
        title: Text('payment_orders.detail.title'.tr()),
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
                    error.toString().replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  SacButton.outline(
                    text: 'common.retry'.tr(),
                    onPressed: () =>
                        ref.invalidate(paymentOrderDetailProvider(orderId)),
                  ),
                ],
              ),
            ),
          ),
          data: (order) => _OrderDetailBody(
            order: order,
            isWorking: actionsState.isWorking,
            onViewPdf: () => _viewPdf(context, ref, order),
            onUploadProof: () => _pickAndUploadProof(context, ref),
            onCancel: () => _confirmCancel(context, ref),
          ),
        ),
      ),
    );
  }

  Future<void> _viewPdf(
    BuildContext context,
    WidgetRef ref,
    PaymentOrder order,
  ) async {
    final path = await ref
        .read(orderActionsNotifierProvider.notifier)
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
          'payment_orders.detail.proof_too_large'.tr(),
          AppColors.error,
        );
      }
      return;
    }

    final file = File(path);
    if (!await file.exists()) return;

    final uploaded =
        await ref.read(orderActionsNotifierProvider.notifier).uploadProof(
              orderId: orderId,
              filePath: path,
              fileName: picked.name,
              mimeType: _mimeFromExtension(picked.extension),
            );

    if (uploaded && context.mounted) {
      _showSnack(
        context,
        'payment_orders.detail.proof_uploaded'.tr(),
        AppColors.secondary,
      );
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'payment_orders.detail.cancel_title'.tr(),
      content: 'payment_orders.detail.cancel_body'.tr(),
      confirmLabel: 'payment_orders.detail.cancel_confirm'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true) return;

    final cancelled = await ref
        .read(orderActionsNotifierProvider.notifier)
        .cancelOrder(orderId);
    if (cancelled && context.mounted) {
      _showSnack(
        context,
        'payment_orders.detail.cancelled'.tr(),
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
      default:
        return 'application/octet-stream';
    }
  }
}

class _OrderDetailBody extends StatelessWidget {
  final PaymentOrder order;
  final bool isWorking;
  final VoidCallback onViewPdf;
  final VoidCallback onUploadProof;
  final VoidCallback onCancel;

  const _OrderDetailBody({
    required this.order,
    required this.isWorking,
    required this.onViewPdf,
    required this.onUploadProof,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final proof = order.latestProof;
    final dateFormat = DateFormat.yMMMd(context.locale.toString());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: folio + estado
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
                    PaymentOrderStatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'payment_orders.detail.total'.tr(),
                  value: formatCentavos(order.totalCentavos, order.currency),
                  emphasized: true,
                ),
                _DetailRow(
                  label: 'payment_orders.detail.unit_cost'.tr(),
                  value:
                      formatCentavos(order.unitCostCentavos, order.currency),
                ),
                _DetailRow(
                  label: 'payment_orders.detail.beneficiaries'.tr(),
                  value: order.lines.length.toString(),
                ),
                _DetailRow(
                  label: 'payment_orders.detail.expires'.tr(),
                  value: dateFormat.format(order.expiresAt.toLocal()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Timeline
          Text(
            'payment_orders.detail.timeline_title'.tr(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 12),
          PaymentOrderTimeline(order: order),
          const SizedBox(height: 18),

          // Comprobante
          if (proof != null) ...[
            Text(
              'payment_orders.detail.proof_title'.tr(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedFile01,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          proof.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: c.text),
                        ),
                      ),
                    ],
                  ),
                  if (proof.status == PaymentOrderProofStatus.rejected &&
                      proof.rejectReason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'payment_orders.detail.reject_reason'.tr(
                        namedArgs: {'reason': proof.rejectReason!},
                      ),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Acciones
          SacButton.outline(
            text: 'payment_orders.detail.view_pdf'.tr(),
            icon: HugeIcons.strokeRoundedPdf01,
            onPressed: isWorking ? null : onViewPdf,
          ),
          if (order.canUploadProof) ...[
            const SizedBox(height: 12),
            SacButton.primary(
              text: order.status == PaymentOrderStatus.proofRejected
                  ? 'payment_orders.detail.reupload_proof'.tr()
                  : 'payment_orders.detail.upload_proof'.tr(),
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
                'payment_orders.detail.cancel_order'.tr(),
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
          Text(
            value,
            style: TextStyle(
              fontSize: emphasized ? 15 : 13,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              color: c.text,
            ),
          ),
        ],
      ),
    );
  }
}
