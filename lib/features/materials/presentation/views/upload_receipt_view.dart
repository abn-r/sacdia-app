import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_date_picker.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';

import '../providers/history_provider.dart';
import '../providers/order_detail_provider.dart';
import '../providers/receipts_provider.dart';
import '../widgets/materials_rows.dart';
import '../widgets/price_input.dart';
import '../widgets/receipt_source_sheet.dart';

const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
const List<String> _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

/// "Subir comprobante": el monto ya trae el total del pedido, la fecha es hoy
/// y el concepto es el folio; solo se elige el archivo y se revisa la vista
/// previa. Los errores salen junto al campo.
///
/// Ruta: /home/materials/order/:folio/receipt
class UploadReceiptView extends ConsumerStatefulWidget {
  const UploadReceiptView({super.key, required this.folioOrId});

  final String folioOrId;

  @override
  ConsumerState<UploadReceiptView> createState() => _UploadReceiptViewState();
}

class _UploadReceiptViewState extends ConsumerState<UploadReceiptView> {
  File? _file;
  String? _fileName;
  int _fileSize = 0;
  bool _fileIsImage = false;
  String? _fileError;

  /// Null until the order loads; then the order total unless the user edits.
  int? _amountCentavos;
  String? _amountError;
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  // ── File ────────────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final source = await showReceiptSourceSheet(context);
    if (source == null || !mounted) return;

    String? path;
    String? name;
    try {
      if (source == ReceiptSource.file) {
        final picked = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: _allowedExtensions,
        );
        path = picked?.path;
        name = picked?.name;
      } else {
        final image = await ImagePicker().pickImage(
          source: source == ReceiptSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2400,
        );
        path = image?.path;
        final extension = image?.name.split('.').last.toLowerCase() ?? 'jpg';
        name = image == null ? null : 'comprobante.$extension';
      }
    } catch (_) {
      if (mounted) {
        setState(() => _fileError = 'materials.receipt.picker_error'.tr());
      }
      return;
    }
    if (path == null || name == null || !mounted) return;

    final file = File(path);
    final size = await file.length();
    if (!mounted) return;

    // Client-side size validation (mirrors backend REQ-CMP-002).
    if (size > _maxFileSizeBytes) {
      setState(() {
        _file = null;
        _fileName = null;
        _fileError = 'materials.receipt.file_too_large'.tr();
      });
      return;
    }

    final extension = name.split('.').last.toLowerCase();
    setState(() {
      _file = file;
      _fileName = name;
      _fileSize = size;
      _fileIsImage = extension != 'pdf';
      _fileError = null;
    });
  }

  // ── Amount and date ─────────────────────────────────────────────────────────

  Future<void> _editAmount(int current) async {
    final value = await showSacSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AmountSheet(initialCentavos: current),
    );
    if (value != null && mounted) {
      setState(() {
        _amountCentavos = value;
        _amountError = null;
      });
    }
  }

  Future<void> _editDate() async {
    final now = DateTime.now();
    final picked = await showSacDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now, // Cannot be a future date.
    );
    if (picked != null && mounted) {
      setState(() => _date = DateUtils.dateOnly(picked));
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit(int amountCentavos, String concept) async {
    var valid = true;
    if (_file == null) {
      setState(() => _fileError = 'materials.receipt.file_required'.tr());
      valid = false;
    }
    if (amountCentavos <= 0) {
      setState(() => _amountError = 'materials.receipt.amount_min'.tr());
      valid = false;
    }
    if (!valid) return;

    await ref.read(uploadReceiptNotifierProvider.notifier).upload(
          UploadReceiptArgs(
            folioOrId: widget.folioOrId,
            file: _file!,
            montoCentavos: amountCentavos,
            refBancariaDeclarada: concept,
            fechaPago: _date,
          ),
        );
  }

  String _dateLabel(BuildContext context) {
    final locale = context.locale.toString();
    final formatted = DateFormat.MMMd(locale).format(_date);
    return DateUtils.isSameDay(_date, DateTime.now())
        ? 'materials.receipt.today'.tr(namedArgs: {'date': formatted})
        : DateFormat.yMMMd(locale).format(_date);
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadReceiptNotifierProvider);
    final orderAsync = ref.watch(orderDetailProvider(widget.folioOrId));
    final c = context.sac;

    ref.listen(uploadReceiptNotifierProvider, (prev, next) {
      if (next.result != null && prev?.result == null) {
        ref.invalidate(orderDetailProvider(widget.folioOrId));
        ref.invalidate(receiptsProvider(widget.folioOrId));
        ref.invalidate(historyProvider);
        if (!context.mounted) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(RouteNames.materialsOrderDetail(widget.folioOrId));
        }
        SacSnackBar.show(
          context,
          'materials.receipt.sent'.tr(),
          isSuccess: true,
        );
      }
      if (next.errorMessage != null && prev?.errorMessage == null) {
        if (context.mounted) {
          SacSnackBar.show(context, next.errorMessage!, isError: true);
        }
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: 'materials.receipt.title'.tr(),
        backgroundColor: c.canvas,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            if (uploadState.isLoading) {
              return _UploadProgress(progress: uploadState.progress);
            }
            return orderAsync.when(
              loading: () => const _FormSkeleton(),
              error: (e, _) => SacErrorState(
                title: 'materials.order.load_error'.tr(),
                message: userErrorMessage(e),
                onRetry: () =>
                    ref.invalidate(orderDetailProvider(widget.folioOrId)),
                padding: SacTopBar.paddingBelowBar(
                  context,
                  const EdgeInsets.all(24),
                ),
              ),
              data: (order) {
                final amount = _amountCentavos ?? order.totalCentavos;
                final concept = order.folioReferencia ?? widget.folioOrId;
                return Stack(
                  children: [
                    ListView(
                      padding: SacTopBar.paddingBelowBar(
                        context,
                        EdgeInsets.only(
                          top: 12,
                          bottom: SacFrostedFooter.height +
                              16 +
                              MediaQuery.paddingOf(context).bottom,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _file == null
                              ? _EmptyFileCard(
                                  hasError: _fileError != null,
                                  onTap: _pickFile,
                                )
                              : _FilePreviewCard(
                                  file: _file!,
                                  name: _fileName ?? '',
                                  isImage: _fileIsImage,
                                  sizeBytes: _fileSize,
                                  onChange: _pickFile,
                                ),
                        ),
                        if (_fileError != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                            child: Text(
                              _fileError!,
                              key: const ValueKey('receipt-file-error'),
                              style: TextStyle(
                                fontSize: SacFontSize.bodySmall,
                                color: c.onErrorContainer,
                              ),
                            ),
                          ),
                        SacGroupedSection(
                          key: const ValueKey('receipt-data'),
                          label: 'materials.receipt.data_section'.tr(),
                          action: const SizedBox.shrink(),
                          dividerIndent: 14,
                          children: [
                            MaterialsKvRow(
                              key: const ValueKey('receipt-amount'),
                              label: 'materials.receipt.amount'.tr(),
                              value: SacMoney.fromCentavos(amount),
                              error: _amountError,
                              onTap: () => _editAmount(amount),
                            ),
                            MaterialsKvRow(
                              key: const ValueKey('receipt-date'),
                              label: 'materials.receipt.date_section'.tr(),
                              value: _dateLabel(context),
                              onTap: _editDate,
                            ),
                            MaterialsKvRow(
                              key: const ValueKey('receipt-concept'),
                              label: 'materials.receipt.concept'.tr(),
                              value: concept,
                              mono: true,
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                          child: Text(
                            'materials.receipt.check_amount'.tr(),
                            style: TextStyle(
                              fontSize: SacFontSize.bodyMedium,
                              height: 1.4,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SacFrostedFooter(
                        child: SacButton.primary(
                          key: const ValueKey('receipt-submit'),
                          text: 'materials.receipt.submit'.tr(),
                          icon: HugeIcons.strokeRoundedSent,
                          onPressed: () => _submit(amount, concept),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ── File cards ────────────────────────────────────────────────────────────────

class _EmptyFileCard extends StatelessWidget {
  const _EmptyFileCard({required this.hasError, required this.onTap});

  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    return Semantics(
      button: true,
      label:
          '${'materials.receipt.add_file'.tr()}. ${'materials.receipt.add_file_hint'.tr()}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          side: BorderSide(
            color: hasError ? c.error : c.border,
            width: hasError ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SacInkWell(
          key: const ValueKey('receipt-add-file'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: buildIcon(
                    HugeIcons.strokeRoundedFileUpload,
                    size: 24,
                    color: accent.color,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'materials.receipt.add_file'.tr(),
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      Text(
                        'materials.receipt.add_file_hint'.tr(),
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          height: 1.35,
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
      ),
    );
  }
}

class _FilePreviewCard extends StatelessWidget {
  const _FilePreviewCard({
    required this.file,
    required this.name,
    required this.isImage,
    required this.sizeBytes,
    required this.onChange,
  });

  final File file;
  final String name;
  final bool isImage;
  final int sizeBytes;
  final VoidCallback onChange;

  String _size() {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final kind = (isImage
            ? 'materials.receipt.kind_photo'
            : 'materials.receipt.kind_pdf')
        .tr();
    Widget icon() => buildIcon(
          isImage
              ? HugeIcons.strokeRoundedImage01
              : HugeIcons.strokeRoundedPdf01,
          size: 26,
          color: accent.color,
        );
    return Container(
      key: const ValueKey('receipt-preview'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
              child: Container(
                width: 56,
                height: 72,
                alignment: Alignment.center,
                color: accent.surface,
                child: isImage
                    ? Image.file(
                        file,
                        width: 56,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => icon(),
                      )
                    : icon(),
              ),
            ),
          ),
          const SizedBox(width: 14),
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
                  '$kind · ${_size()}',
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  button: true,
                  label: 'materials.receipt.change'.tr(),
                  excludeSemantics: true,
                  onTap: onChange,
                  child: SacInkWell(
                    key: const ValueKey('receipt-change'),
                    onTap: onChange,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: 1,
                        child: Text(
                          'materials.receipt.change'.tr(),
                          style: TextStyle(
                            fontSize: SacFontSize.bodyMedium,
                            fontWeight: FontWeight.w600,
                            color: accent.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Amount sheet ──────────────────────────────────────────────────────────────

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.initialCentavos});

  final int initialCentavos;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late int _centavos = widget.initialCentavos;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLG),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SacSheetGrabber(),
                const SizedBox(height: 8),
                PriceInput(
                  label: 'materials.receipt.amount'.tr(),
                  initialCentavos: widget.initialCentavos,
                  onChanged: (v) => setState(() => _centavos = v),
                ),
                const SizedBox(height: 16),
                SacButton.primary(
                  key: const ValueKey('receipt-amount-done'),
                  text: 'common.done'.tr(),
                  isEnabled: _centavos > 0,
                  onPressed: () => Navigator.of(context).pop(_centavos),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Progress and skeleton ─────────────────────────────────────────────────────

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCloudUpload,
              size: 56,
              color: accent.color,
            ),
            const SizedBox(height: 16),
            Text(
              'materials.receipt.sending'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            progress > 0
                ? SacTweenedBar(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: accent.surface,
                    color: accent.color,
                  )
                : LinearProgressIndicator(
                    backgroundColor: accent.surface,
                    color: accent.color,
                  ),
            if (progress > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: context.sac.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) {
    return SacShimmer(
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: SacTopBar.paddingBelowBar(
            context,
            const EdgeInsets.fromLTRB(20, 12, 20, 32),
          ),
          children: const [
            SacSkeletonBox(height: 82, radius: AppTheme.radiusMD),
            SizedBox(height: 28),
            SacSkeletonBox(width: 90, height: 10),
            SizedBox(height: 12),
            SacSkeletonBox(height: 150, radius: AppTheme.radiusMD),
          ],
        ),
      ),
    );
  }
}
