import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../domain/entities/camporee_payment.dart';
import '../providers/camporees_providers.dart';

/// Vista de pagos de un miembro en un camporee.
///
/// Muestra los pagos existentes y permite registrar uno nuevo.
class CamporeePaymentsView extends ConsumerWidget {
  final int camporeeId;
  final String memberId;
  final String? memberName;

  const CamporeePaymentsView({
    super.key,
    required this.camporeeId,
    required this.memberId,
    this.memberName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = CamporeePaymentParams(
      camporeeId: camporeeId,
      memberId: memberId,
    );
    final paymentsAsync = ref.watch(camporeeMemberPaymentsProvider(params));
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          memberName != null ? 'camporees.payments.title'.tr(namedArgs: {'name': memberName!}) : 'camporees.payments.title_fallback'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: c.text,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              color: AppColors.primary,
              size: 22,
            ),
            tooltip: 'camporees.payments.register_tooltip'.tr(),
            onPressed: () => _openPaymentForm(context, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (e, _) => _ErrorBody(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(camporeeMemberPaymentsProvider(params)),
        ),
        data: (payments) {
          if (payments.isEmpty) {
            return _EmptyBody(
              onAdd: () => _openPaymentForm(context, ref),
            );
          }

          final totalAmount = payments.fold<double>(
            0,
            (sum, p) => sum + p.amount,
          );

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.invalidate(camporeeMemberPaymentsProvider(params)),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Summary card
                _SummaryCard(
                  totalAmount: totalAmount,
                  paymentCount: payments.length,
                ),
                const SizedBox(height: 16),

                // Payment list
                ...payments.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PaymentCard(payment: entry.value),
                      ),
                    ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPaymentForm(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedAdd01,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          'camporees.payments.register_button'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _openPaymentForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CamporeePaymentFormSheet(
        camporeeId: camporeeId,
        memberId: memberId,
      ),
    ).then((_) {
      final params = CamporeePaymentParams(
        camporeeId: camporeeId,
        memberId: memberId,
      );
      ref.invalidate(camporeeMemberPaymentsProvider(params));
    });
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double totalAmount;
  final int paymentCount;

  const _SummaryCard({
    required this.totalAmount,
    required this.paymentCount,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 2,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedMoney01,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'camporees.payments.total_paid'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryDark,
                  ),
                ),
                Text(
                  currencyFmt.format(totalAmount),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              paymentCount == 1
                  ? 'camporees.payments.payment_count_one'.tr(namedArgs: {'count': '$paymentCount'})
                  : 'camporees.payments.payment_count_other'.tr(namedArgs: {'count': '$paymentCount'}),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment Card ──────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final CamporeePayment payment;

  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final statusCfg = _statusConfig(payment.paymentStatus);
    final currencyFmt = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 2,
    );
    final dateFmt = DateFormat('dd/MM/yyyy', 'es');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusCfg.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedMoney01,
                  color: statusCfg.fg,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _paymentTypeLabel(payment.paymentType),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    if (payment.paymentDate != null)
                      Text(
                        dateFmt.format(payment.paymentDate!.toLocal()),
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                currencyFmt.format(payment.amount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (payment.reference != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTag01,
                  color: c.textTertiary,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'Ref: ${payment.reference}',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ],
          if (payment.notes != null) ...[
            const SizedBox(height: 6),
            Text(
              payment.notes!,
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Status badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusCfg.bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              payment.paymentStatus.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusCfg.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _paymentTypeLabel(String type) {
    switch (type) {
      case 'cash':
        return 'camporees.payments.payment_type_cash'.tr();
      case 'transfer':
        return 'camporees.payments.payment_type_transfer'.tr();
      case 'check':
        return 'camporees.payments.payment_type_check'.tr();
      case 'card':
        return 'camporees.payments.payment_type_card'.tr();
      default:
        return type;
    }
  }

  _StatusConfig _statusConfig(CamporeePaymentStatus status) {
    switch (status) {
      case CamporeePaymentStatus.verified:
        return _StatusConfig(
          bg: AppColors.secondaryLight,
          fg: AppColors.secondaryDark,
        );
      case CamporeePaymentStatus.rejected:
        return _StatusConfig(
          bg: AppColors.errorLight,
          fg: AppColors.errorDark,
        );
      case CamporeePaymentStatus.pending:
        return _StatusConfig(
          bg: AppColors.accentLight,
          fg: AppColors.accentDark,
        );
    }
  }
}

class _StatusConfig {
  final Color bg;
  final Color fg;

  const _StatusConfig({required this.bg, required this.fg});
}

// ── Payment Form Sheet ────────────────────────────────────────────────────────

/// Modal bottom sheet para registrar un pago de camporee.
class CamporeePaymentFormSheet extends ConsumerStatefulWidget {
  final int camporeeId;
  final String memberId;

  const CamporeePaymentFormSheet({
    super.key,
    required this.camporeeId,
    required this.memberId,
  });

  @override
  ConsumerState<CamporeePaymentFormSheet> createState() =>
      _CamporeePaymentFormSheetState();
}

class _CamporeePaymentFormSheetState
    extends ConsumerState<CamporeePaymentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _paymentType = 'cash';
  DateTime? _paymentDate;

  List<(String, String)> get _paymentTypes => [
    ('cash', 'camporees.payments.payment_type_cash'.tr()),
    ('transfer', 'camporees.payments.payment_type_transfer'.tr()),
    ('check', 'camporees.payments.payment_type_check'.tr()),
    ('card', 'camporees.payments.payment_type_card'.tr()),
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = CamporeePaymentParams(
      camporeeId: widget.camporeeId,
      memberId: widget.memberId,
    );
    final formState = ref.watch(createCamporeePaymentProvider(params));
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'camporees.payments.form_title'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 20),

                // Error
                if (formState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedAlert02,
                          color: AppColors.error,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formState.errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Monto
                Text(
                  'camporees.payments.amount_label'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration(
                    hintText: '0.00',
                    context: context,
                    prefixIcon: HugeIcons.strokeRoundedMoney01,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'camporees.payments.amount_required'.tr();
                    }
                    final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
                    if (parsed == null || parsed <= 0) {
                      return 'camporees.payments.amount_invalid'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Tipo de pago
                Text(
                  'camporees.payments.payment_type_label'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(12),
                    color: c.surface,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _paymentType,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      borderRadius: BorderRadius.circular(12),
                      items: _paymentTypes
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.$1,
                              child: Text(t.$2),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _paymentType = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Referencia (opcional)
                Text(
                  'camporees.payments.reference_label'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _referenceCtrl,
                  decoration: _inputDecoration(
                    hintText: 'camporees.payments.reference_hint'.tr(),
                    context: context,
                    prefixIcon: HugeIcons.strokeRoundedTag01,
                  ),
                ),
                const SizedBox(height: 16),

                // Fecha de pago
                Text(
                  'camporees.payments.payment_date_label'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _pickDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(12),
                      color: c.surface,
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar01,
                          color: c.textTertiary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _paymentDate != null
                              ? DateFormat('dd/MM/yyyy', 'es')
                                  .format(_paymentDate!)
                              : 'camporees.payments.select_date'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            color: _paymentDate != null
                                ? c.text
                                : c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notas (opcional)
                Text(
                  'camporees.payments.notes_label'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: _inputDecoration(
                    hintText: 'camporees.payments.notes_hint'.tr(),
                    context: context,
                  ),
                ),
                const SizedBox(height: 24),

                SacButton.primary(
                  text: 'camporees.payments.register_button'.tr(),
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  isLoading: formState.isLoading,
                  onPressed: formState.isLoading ? null : _submit,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required BuildContext context,
    dynamic prefixIcon,
  }) {
    final c = context.sac;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 13, color: c.textTertiary),
      prefixIcon: prefixIcon != null
          ? HugeIcon(icon: prefixIcon, color: c.textTertiary, size: 18)
          : null,
      filled: true,
      fillColor: c.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final params = CamporeePaymentParams(
      camporeeId: widget.camporeeId,
      memberId: widget.memberId,
    );
    ref.read(createCamporeePaymentProvider(params).notifier).reset();

    final amount = double.parse(
        _amountCtrl.text.trim().replaceAll(',', '.'));
    final reference =
        _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim();
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    final success = await ref
        .read(createCamporeePaymentProvider(params).notifier)
        .create(
          amount: amount,
          paymentType: _paymentType,
          reference: reference,
          paymentDate: _paymentDate,
          notes: notes,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('camporees.payments.success'.tr()),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pop();
    }
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  final VoidCallback? onAdd;

  const _EmptyBody({this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedMoney01,
              color: c.textTertiary,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'camporees.payments.empty'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'camporees.payments.empty_hint'.tr(),
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'camporees.payments.register_button'.tr(),
              icon: HugeIcons.strokeRoundedAdd01,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorBody({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            SacButton.primary(
              text: 'common.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
