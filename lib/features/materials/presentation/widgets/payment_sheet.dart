import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../domain/entities/order.dart';

/// Opens the payment data over the order. Resolves to true when the user says
/// they already paid ("Ya pagué · subir comprobante").
Future<bool?> showPaymentSheet(BuildContext context, Order order) {
  return showSacSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PaymentSheet(order: order),
  );
}

/// Big amount and the bank data, each row with a 44pt copy button.
class PaymentSheet extends StatelessWidget {
  const PaymentSheet({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final folio = order.folioReferencia ?? '';
    String? clean(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    final bank = clean(order.bankName);
    final clabe = clean(order.bankAccountClabe);
    final holder = clean(order.accountHolder);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SacSheetGrabber(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'materials.payment.transfer'.tr().toUpperCase(),
                        style: TextStyle(
                          fontSize: SacFontSize.labelSmall,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: c.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      SacMoney.fromCentavos(order.totalCentavos),
                      key: const ValueKey('payment-amount'),
                      style: TextStyle(
                        fontSize: SacFontSize.metricSmall,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: c.text,
                        fontFeatures: SacMoney.tabularFigures,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: c.surface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        side: BorderSide(color: c.border),
                      ),
                      child: Column(
                        children: [
                          if (bank != null)
                            _DataRow(
                              label: 'materials.payment.bank'.tr(),
                              value: bank,
                            ),
                          if (clabe != null)
                            _DataRow(
                              key: const ValueKey('payment-clabe'),
                              label: 'materials.payment.clabe'.tr(),
                              value: clabe,
                              mono: true,
                              copyable: true,
                            ),
                          if (holder != null)
                            _DataRow(
                              key: const ValueKey('payment-holder'),
                              label: 'materials.payment.holder'.tr(),
                              value: holder,
                              copyable: true,
                            ),
                          if (folio.isNotEmpty)
                            _DataRow(
                              key: const ValueKey('payment-concept'),
                              label: 'materials.payment.concept'.tr(),
                              hint: 'materials.payment.concept_hint'.tr(),
                              value: folio,
                              mono: true,
                              copyable: true,
                              isLast: true,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'materials.payment.transfer_hint'.tr(),
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        height: 1.4,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SacButton.primary(
                key: const ValueKey('payment-paid'),
                text: 'materials.payment.paid_upload'.tr(),
                icon: HugeIcons.strokeRoundedFileUpload,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatefulWidget {
  const _DataRow({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.mono = false,
    this.copyable = false,
    this.isLast = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool mono;
  final bool copyable;
  final bool isLast;

  @override
  State<_DataRow> createState() => _DataRowState();
}

class _DataRowState extends State<_DataRow> {
  static const _feedbackDuration = Duration(milliseconds: 1500);

  Timer? _resetTimer;
  bool _justCopied = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final label = widget.label;
    final value = widget.value;
    final mono = widget.mono;
    final copyable = widget.copyable;
    final isLast = widget.isLast;
    final hint = widget.hint;
    final reduceMotion = SacMotion.reduceMotionOf(context);
    final copyLabel = _justCopied
        ? 'materials.payment.copied'.tr(namedArgs: {'label': label})
        : 'materials.payment.copy_label'.tr(namedArgs: {'label': label});
    return DecoratedBox(
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: c.divider)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 8, copyable ? 4 : 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The value is shown whole (a CLABE is 18 digits).
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: mono
                            ? SacFontSize.titleSmall
                            : SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                        fontFamily: mono ? 'monospace' : null,
                        height: 1.3,
                        color: c.text,
                      ),
                    ),
                    Text(
                      hint == null ? label : '$label · $hint',
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        height: 1.35,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (copyable)
                Semantics(
                  button: true,
                  liveRegion: _justCopied,
                  label: copyLabel,
                  excludeSemantics: true,
                  onTap: () => _copy(context),
                  child: SacInkWell(
                    onTap: () => _copy(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 150),
                          child: _justCopied
                              ? HugeIcon(
                                  key: const ValueKey('copied-check'),
                                  icon: HugeIcons.strokeRoundedTick02,
                                  size: 20,
                                  color: c.success,
                                )
                              : HugeIcon(
                                  key: const ValueKey('copy-icon'),
                                  icon: HugeIcons.strokeRoundedCopy01,
                                  size: 20,
                                  color: SacAccent.of(context).color,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.value));
    HapticFeedback.selectionClick();
    // The modal sheet covers any snackbar, so the feedback lives on the row.
    setState(() => _justCopied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(_feedbackDuration, () {
      if (mounted) setState(() => _justCopied = false);
    });
  }
}
