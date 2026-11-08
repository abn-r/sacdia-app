import 'dart:io';
import 'package:sacdia_app/core/utils/money_format.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

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
                onViewProof: (proof) => _viewProof(context, ref, proof),
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

  Future<void> _viewProof(
    BuildContext context,
    WidgetRef ref,
    PaymentOrderProof proof,
  ) async {
    final url =
        await ref.read(orderActionsNotifierProvider.notifier).proofUrl(orderId);
    if (url == null || !context.mounted) return;
    if (proof.mimeType == 'application/pdf') {
      SacPdfViewer.show(context, pdfSource: url, title: proof.fileName);
    } else {
      SacImageViewer.show(context, imageUrl: url, title: proof.fileName);
    }
  }

  /// Camera, photo library or a file (PDF), then a preview before sending.
  Future<void> _pickAndUploadProof(BuildContext context, WidgetRef ref) async {
    final source = await showSacSheet<_ProofSource>(
      context: context,
      builder: (_) => const _ProofSourceSheet(),
    );
    if (source == null || !context.mounted) return;

    final picked = await _pickProof(source);
    if (picked == null || !context.mounted) return;

    final file = File(picked.path);
    if (!await file.exists()) return;
    if (await file.length() > _proofMaxSizeBytes) {
      if (context.mounted) {
        _showSnack(
          context,
          'payment_orders.detail.proof_too_large'.tr(),
          isError: true,
        );
      }
      return;
    }
    if (!context.mounted) return;

    final confirmed = await SacDialog.show(
      context,
      title: 'payment_orders.detail.proof_confirm_title'.tr(),
      body: _ProofPreview(file: picked),
      confirmLabel: 'payment_orders.detail.proof_send'.tr(),
      cancelLabel: 'common.cancel'.tr(),
    );
    if (confirmed != true || !context.mounted) return;

    final uploaded =
        await ref.read(orderActionsNotifierProvider.notifier).uploadProof(
              orderId: orderId,
              filePath: picked.path,
              fileName: picked.name,
              mimeType: picked.mimeType,
            );

    if (uploaded && context.mounted) {
      _showSnack(
        context,
        'payment_orders.detail.proof_uploaded'.tr(),
        isSuccess: true,
      );
    }
  }

  Future<_PickedProof?> _pickProof(_ProofSource source) async {
    if (source == _ProofSource.file) {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: _proofAllowedExtensions,
      );
      final path = picked?.path;
      if (picked == null || path == null) return null;
      return _PickedProof(
        path: path,
        name: picked.name,
        mimeType: _mimeFromExtension(picked.extension),
      );
    }

    final image = await ImagePicker().pickImage(
      source: source == _ProofSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2400,
    );
    if (image == null) return null;
    final extension = image.name.split('.').last.toLowerCase();
    final mimeType = _mimeFromExtension(extension);
    return _PickedProof(
      path: image.path,
      // The picker names files like "image_picker_<uuid>.jpg"; the reviewer
      // and the director only need to know it is the receipt.
      name: 'comprobante.$extension',
      // HEIC and other formats are re-encoded as JPEG by imageQuality.
      mimeType:
          mimeType == 'application/octet-stream' ? 'image/jpeg' : mimeType,
    );
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

/// Folio and status up top, then grouped rows: amounts, status path, proof
/// and the PDF. Uploading the proof is pinned at the bottom; cancelling is
/// a destructive row at the end.
class _OrderDetailBody extends StatelessWidget {
  final PaymentOrder order;
  final bool isWorking;
  final VoidCallback onViewPdf;
  final VoidCallback onUploadProof;
  final ValueChanged<PaymentOrderProof> onViewProof;
  final VoidCallback onCancel;

  const _OrderDetailBody({
    required this.order,
    required this.isWorking,
    required this.onViewPdf,
    required this.onUploadProof,
    required this.onViewProof,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final proof = order.latestProof;
    final dateFormat = DateFormat.yMMMd(context.locale.toString());
    final rejected = proof?.status == PaymentOrderProofStatus.rejected &&
        proof?.rejectReason != null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: SacTopBar.paddingBelowBar(
              context,
              const EdgeInsets.fromLTRB(20, 16, 20, 32),
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        order.folioReference,
                        style: TextStyle(
                          fontSize: SacFontSize.titleLarge,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  PaymentOrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 20),
              SacSettingsGroup(
                key: const Key('payment-order-amounts'),
                title: 'payment_orders.detail.amounts_title'.tr().toUpperCase(),
                children: [
                  SacSettingsValueTile(
                    icon: HugeIcons.strokeRoundedMoney03,
                    label: 'payment_orders.detail.total'.tr(),
                    value: SacMoney.fromCentavos(order.totalCentavos),
                    emphasis: true,
                  ),
                  const SacSettingsDivider(),
                  SacSettingsValueTile(
                    icon: HugeIcons.strokeRoundedTicket01,
                    label: 'payment_orders.detail.unit_cost'.tr(),
                    value: SacMoney.fromCentavos(order.unitCostCentavos),
                  ),
                  const SacSettingsDivider(),
                  SacSettingsValueTile(
                    icon: HugeIcons.strokeRoundedUserGroup,
                    label: 'payment_orders.detail.beneficiaries'.tr(),
                    value: order.lines.length.toString(),
                  ),
                  const SacSettingsDivider(),
                  SacSettingsValueTile(
                    icon: HugeIcons.strokeRoundedCalendar03,
                    label: 'payment_orders.detail.expires'.tr(),
                    value: dateFormat.format(order.expiresAt.toLocal()),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SacSettingsGroup(
                title:
                    'payment_orders.detail.timeline_title'.tr().toUpperCase(),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: PaymentOrderTimeline(order: order),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SacSettingsGroup(
                title:
                    'payment_orders.detail.documents_title'.tr().toUpperCase(),
                children: [
                  SacSettingsTile(
                    key: const Key('payment-order-view-pdf'),
                    icon: HugeIcons.strokeRoundedPdf01,
                    title: 'payment_orders.detail.view_pdf'.tr(),
                    onTap: isWorking ? null : onViewPdf,
                  ),
                  if (proof != null) ...[
                    const SacSettingsDivider(),
                    SacSettingsTile(
                      key: const Key('payment-order-view-proof'),
                      icon: HugeIcons.strokeRoundedFile01,
                      title: proof.fileName,
                      subtitle: rejected
                          ? '${'payment_orders.detail.reject_reason'.tr()}: '
                              '${proof.rejectReason}'
                          : 'payment_orders.detail.proof_title'.tr(),
                      destructive: rejected,
                      onTap: isWorking ? null : () => onViewProof(proof),
                    ),
                  ],
                ],
              ),
              if (order.canCancel) ...[
                const SizedBox(height: 24),
                SacSettingsGroup(
                  children: [
                    SacSettingsTile(
                      key: const Key('payment-order-cancel'),
                      icon: HugeIcons.strokeRoundedCancelCircle,
                      title: 'payment_orders.detail.cancel_order'.tr(),
                      destructive: true,
                      onTap: isWorking ? null : onCancel,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (order.canUploadProof)
          SacPinnedActionBar(
            child: SacButton.primary(
              key: const Key('payment-order-upload-proof'),
              text: order.status == PaymentOrderStatus.proofRejected
                  ? 'payment_orders.detail.reupload_proof'.tr()
                  : 'payment_orders.detail.upload_proof'.tr(),
              icon: HugeIcons.strokeRoundedUpload01,
              isLoading: isWorking,
              onPressed: isWorking ? null : onUploadProof,
            ),
          ),
      ],
    );
  }
}

enum _ProofSource { camera, gallery, file }

class _PickedProof {
  final String path;
  final String name;
  final String mimeType;

  const _PickedProof({
    required this.path,
    required this.name,
    required this.mimeType,
  });

  bool get isImage => mimeType.startsWith('image/');
}

class _ProofSourceSheet extends StatelessWidget {
  const _ProofSourceSheet();

  @override
  Widget build(BuildContext context) {
    void pick(_ProofSource source) => Navigator.of(context).pop(source);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SacSheetHeader(title: 'payment_orders.detail.proof_source'.tr()),
            SacSettingsGroup(
              children: [
                SacSettingsTile(
                  key: const Key('proof-source-camera'),
                  icon: HugeIcons.strokeRoundedCamera01,
                  title: 'payment_orders.detail.proof_source_camera'.tr(),
                  onTap: () => pick(_ProofSource.camera),
                ),
                const SacSettingsDivider(),
                SacSettingsTile(
                  key: const Key('proof-source-gallery'),
                  icon: HugeIcons.strokeRoundedImage01,
                  title: 'payment_orders.detail.proof_source_gallery'.tr(),
                  onTap: () => pick(_ProofSource.gallery),
                ),
                const SacSettingsDivider(),
                SacSettingsTile(
                  key: const Key('proof-source-file'),
                  icon: HugeIcons.strokeRoundedPdf01,
                  title: 'payment_orders.detail.proof_source_file'.tr(),
                  subtitle: 'payment_orders.detail.proof_source_file_hint'.tr(),
                  onTap: () => pick(_ProofSource.file),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What will be sent: the photo itself, or the file name for a PDF.
class _ProofPreview extends StatelessWidget {
  final _PickedProof file;

  const _ProofPreview({required this.file});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    if (file.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: Image.file(
            File(file.path),
            key: const Key('proof-preview-image'),
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedPdf01,
          size: 24,
          color: c.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            file.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: SacFontSize.bodyMedium, color: c.text),
          ),
        ),
      ],
    );
  }
}
