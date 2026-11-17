import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/back_or_home.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';

import '../../../insurance/domain/entities/insurance_overview.dart';
import '../../../insurance/presentation/providers/insurance_providers.dart';
import '../../../insurance/presentation/utils/insurance_formatting.dart';
import '../../../insurance/presentation/widgets/insurance_action_sheet.dart';
import '../../domain/entities/payment_order.dart';
import '../providers/payment_orders_providers.dart';
import '../utils/order_state_presentation.dart';

const _proofAllowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
const _proofMaxSizeBytes = 10 * 1024 * 1024;

/// Orden de pago: solo el estado actual arriba (con "Paso N de M"); al tocarlo
/// una hoja muestra todos los estados. Abajo, el importe, a quién cubre, los
/// documentos y una sola acción: subir el recibo. Cancelar va en el menú.
class PaymentOrderDetailView extends ConsumerWidget {
  final String orderId;

  const PaymentOrderDetailView({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(paymentOrderDetailProvider(orderId));
    final actionsState = ref.watch(orderActionsNotifierProvider);
    final canManage = ref.watch(canIssuePaymentOrdersProvider).value ?? false;
    final c = context.sac;
    final order = orderAsync.value;

    ref.listen(orderActionsNotifierProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null && message != previous?.errorMessage) {
        _showSnack(context, message, isError: true);
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: order?.folioReference ?? '',
        backgroundColor: c.canvas,
        frosted: true,
        onBack: () => backOrHome(context),
        actions: [
          if (order != null && order.canCancel && canManage)
            IconButton(
              key: const Key('order-more'),
              tooltip: tr('payment_orders.detail.more'),
              onPressed: actionsState.isWorking
                  ? null
                  : () => _confirmCancel(context, ref, order),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedMoreHorizontal,
                size: 22,
                color: c.text,
              ),
            ),
        ],
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => orderAsync.when(
            loading: () => const Center(child: SacLoading()),
            error: (error, _) => SacErrorState(
              title: tr('common.error_state.title'),
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
              canManage: canManage,
              onViewPdf: () => _viewPdf(context, ref, order),
              onUploadProof: () => _pickAndUploadProof(context, ref),
              onViewProof: (proof) => _viewProof(context, ref, proof),
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

  /// One bottom sheet that says what cancelling does (who is freed, and not
  /// to cancel an order already paid) and confirms it. No intermediate menu.
  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    PaymentOrder order,
  ) async {
    final names = [
      for (final line in order.lines)
        if (line.beneficiaryName.isNotEmpty) line.beneficiaryName,
    ];
    final count = order.lines.length;
    final confirmed = await showInsuranceActionSheet(
      context,
      title: 'payment_orders.detail.cancel_sheet_title'
          .tr(namedArgs: {'folio': order.folioReference}),
      body: (count == 1
              ? 'payment_orders.detail.cancel_sheet_body_one'
              : 'payment_orders.detail.cancel_sheet_body_other')
          .tr(namedArgs: {'count': '$count'}),
      content: names.isEmpty ? null : _CancelPeople(names: names),
      primaryLabel: 'payment_orders.detail.cancel_order'.tr(),
      primaryIcon: HugeIcons.strokeRoundedCancelCircle,
      secondaryLabel: 'payment_orders.detail.cancel_sheet_back'.tr(),
      destructive: true,
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

/// Estado arriba, luego importe, a quién cubre y documentos. Subir el recibo
/// queda fijo abajo.
class _OrderDetailBody extends ConsumerWidget {
  final PaymentOrder order;
  final bool isWorking;
  final bool canManage;
  final VoidCallback onViewPdf;
  final VoidCallback onUploadProof;
  final ValueChanged<PaymentOrderProof> onViewProof;

  const _OrderDetailBody({
    required this.order,
    required this.isWorking,
    required this.canManage,
    required this.onViewPdf,
    required this.onUploadProof,
    required this.onViewProof,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final isInsurance = order.purpose == PaymentOrderPurpose.insurance;
    // The year and the people's roles come from the insurance overview when
    // the user can read it; the order works without them.
    final overview =
        isInsurance ? ref.watch(insuranceOverviewProvider).value : null;
    final year = overview?.year?.label;
    final proof = order.latestProof;
    final rejectedReason = proof?.status == PaymentOrderProofStatus.rejected
        ? proof?.rejectReason?.trim()
        : null;
    final state = orderStatePresentation(context, order, yearLabel: year);
    final showUpload = order.canUploadProof && canManage;
    final lines = [...order.lines]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    return Stack(
      children: [
        ListView(
          padding: SacTopBar.paddingBelowBar(
            context,
            EdgeInsets.only(
              top: 12,
              // Clear the fixed footer (button + two-line note + home
              // indicator) so the last section is never hidden under it.
              bottom: 32 +
                  (showUpload ? 150 + MediaQuery.paddingOf(context).bottom : 0),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SacStatePanel(
                key: const Key('payment-order-state-panel'),
                style: state.style,
                title: state.title,
                message: state.message,
                stepLabel: state.stepLabel,
                semanticsHint: tr('payment_orders.state.panel_hint'),
                onTap: () => showSacStatesSheet(
                  context,
                  title: tr('payment_orders.state.sheet_title'),
                  subtitle: order.folioReference,
                  steps: state.steps,
                  kindLabels: orderStateKindLabels(),
                ),
              ),
            ),
            if (rejectedReason != null && rejectedReason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Container(
                  key: const Key('payment-order-reject-reason'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: c.errorContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('payment_orders.detail.reject_reason'),
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          fontWeight: FontWeight.w700,
                          color: c.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '«$rejectedReason»',
                        style: TextStyle(
                          fontSize: SacFontSize.titleSmall,
                          height: 1.4,
                          color: c.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SacGroupedSection(
              key: const Key('payment-order-amounts'),
              label: tr('payment_orders.detail.amounts_title'),
              action: const SizedBox.shrink(),
              dividerIndent: 14,
              children: [
                _Kv(
                  label: tr('payment_orders.detail.total'),
                  value: SacMoney.fromCentavos(order.totalCentavos),
                  emphasis: true,
                ),
                _Kv(
                  label: tr('payment_orders.detail.unit_cost'),
                  value: SacMoney.fromCentavos(order.unitCostCentavos),
                ),
                if (isInsurance && year != null && year.isNotEmpty)
                  _Kv(
                    label: tr('payment_orders.detail.covers'),
                    value: tr(
                      'payment_orders.detail.covers_year',
                      namedArgs: {'year': year},
                    ),
                  ),
              ],
            ),
            if (lines.isNotEmpty)
              SacGroupedSection(
                key: const Key('payment-order-people'),
                label: tr('payment_orders.detail.covers_people'),
                children: [
                  for (final line in lines)
                    _PersonRow(
                      line: line,
                      person: overview?.personById(line.beneficiaryUserId),
                    ),
                ],
              ),
            SacGroupedSection(
              key: const Key('payment-order-documents'),
              label: tr('payment_orders.detail.documents_title'),
              children: [
                _DocRow(
                  key: const Key('payment-order-view-pdf'),
                  icon: HugeIcons.strokeRoundedPdf01,
                  title: tr('payment_orders.detail.view_pdf'),
                  detail: tr('payment_orders.detail.pdf_hint'),
                  onTap: isWorking ? null : onViewPdf,
                ),
                if (proof != null)
                  _DocRow(
                    key: const Key('payment-order-view-proof'),
                    icon: HugeIcons.strokeRoundedImage01,
                    title: tr('payment_orders.detail.proof_title'),
                    detail: _proofDetail(context, proof),
                    detailIsError:
                        proof.status == PaymentOrderProofStatus.rejected,
                    onTap: isWorking ? null : () => onViewProof(proof),
                  ),
              ],
            ),
          ],
        ),
        if (showUpload)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SacPinnedActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SacButton.primary(
                    key: const Key('payment-order-upload-proof'),
                    text: order.status == PaymentOrderStatus.proofRejected
                        ? tr('payment_orders.detail.reupload_proof')
                        : tr('payment_orders.detail.upload_proof'),
                    icon: HugeIcons.strokeRoundedUpload01,
                    isLoading: isWorking,
                    onPressed: isWorking ? null : onUploadProof,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('payment_orders.detail.proof_note'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _proofDetail(BuildContext context, PaymentOrderProof proof) {
    final date = proof.createdAt.millisecondsSinceEpoch > 0
        ? DateFormat.MMMd(context.locale.toString())
            .format(proof.createdAt.toLocal())
        : null;
    final label = switch (proof.status) {
      PaymentOrderProofStatus.rejected =>
        tr('payment_orders.detail.proof_rejected'),
      PaymentOrderProofStatus.approved =>
        tr('payment_orders.detail.proof_approved'),
      PaymentOrderProofStatus.submitted =>
        tr('payment_orders.detail.proof_sent'),
    };
    return date == null ? label : '$label · $date';
  }
}

class _Kv extends StatelessWidget {
  const _Kv({required this.label, required this.value, this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      container: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          // Label takes the free space; the value keeps its natural width
          // (capped at 65%) and hugs the trailing edge, so the amounts line
          // up on the right and "Año eclesiástico 2026" stays on one line.
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: emphasis
                          ? SacFontSize.titleMedium
                          : SacFontSize.titleSmall,
                      fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
                      color: emphasis ? c.text : c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: constraints.maxWidth * 0.65),
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
                      color: emphasis ? c.text : c.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.line, required this.person});

  final PaymentOrderLine line;
  final InsurancePerson? person;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final name = line.beneficiaryName.isNotEmpty
        ? line.beneficiaryName
        : tr('payment_orders.detail.unnamed');
    final staff = person?.isStaff ?? line.isStaff;
    final detail = person != null && staff
        ? insuranceRoleLine(person!)
        : tr(
            staff
                ? 'payment_orders.detail.role_staff'
                : 'payment_orders.detail.role_member',
          );
    return Semantics(
      container: true,
      label: '$name, $detail',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              SacMemberAvatar(name: name, imageUrl: person?.picture, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.detailIsError = false,
  });

  final HugeIconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;
  final bool detailIsError;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacInkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS + 2),
                ),
                child: HugeIcon(icon: icon, size: 20, color: c.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: detailIsError
                            ? c.onErrorContainer
                            : c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
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

/// Who is freed when the order is cancelled, plus the "already paid" guard.
class _CancelPeople extends StatelessWidget {
  const _CancelPeople({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (final name in names)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedUser,
                            size: 16,
                            color: c.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: SacFontSize.titleSmall,
                              color: c.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: 16,
                color: c.warning,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'payment_orders.detail.cancel_sheet_paid_hint'.tr(),
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  height: 1.4,
                  color: c.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
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
