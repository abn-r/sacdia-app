import 'dart:io';
import 'package:sacdia_app/core/utils/money_format.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../domain/entities/payment_order.dart';
import '../providers/payment_orders_providers.dart';
import '../widgets/payment_order_widgets.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

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
        _showSnack(context, message, isError: true);
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'payment_orders.detail.title'.tr(),
          backgroundColor: c.surface,
          foregroundColor: c.text,
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: orderAsync.when(
              loading: () => const Center(child: SacLoading()),
              error: (error, _) => SacErrorState(
                title: 'common.error_state.title'.tr(),
                message: userErrorMessage(error),
                onRetry: () =>
                    ref.invalidate(paymentOrderDetailProvider(orderId)),
                padding: SacTopBar.paddingBelowBar(
                  context,
                  const EdgeInsets.all(24),
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
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _proofAllowedExtensions,
    );
    if (picked == null) return;

    final path = picked.path;
    if (path == null) return;

    if ((await picked.length() ?? 0) > _proofMaxSizeBytes) {
      if (context.mounted) {
        _showSnack(
          context,
          'payment_orders.detail.proof_too_large'.tr(),
          isError: true,
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
        isSuccess: true,
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
        isSuccess: true,
      );
    }
  }

  void _showSnack(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    SacSnackBar.show(
      context,
      message,
      isError: isError,
      isSuccess: isSuccess,
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
      padding: SacTopBar.paddingBelowBar(context, const EdgeInsets.all(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: folio + estado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
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
                          fontSize: SacFontSize.headlineSmall,
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
                  value: SacMoney.fromCentavos(order.totalCentavos),
                  emphasized: true,
                ),
                _DetailRow(
                  label: 'payment_orders.detail.unit_cost'.tr(),
                  value: SacMoney.fromCentavos(order.unitCostCentavos),
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
              fontSize: SacFontSize.titleMedium,
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
                fontSize: SacFontSize.titleMedium,
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
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
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
                        color: SacAccent.of(context).color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          proof.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: SacFontSize.bodyMedium, color: c.text),
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
                        fontSize: SacFontSize.bodySmall,
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
            SacPressable(
              listenOnly: true,
              child: SacButton.text(
                text: 'payment_orders.detail.cancel_order'.tr(),
                color: context.sac.error,
                onPressed: isWorking ? null : onCancel,
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
            style: TextStyle(
                fontSize: SacFontSize.bodyMedium, color: c.textSecondary),
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
