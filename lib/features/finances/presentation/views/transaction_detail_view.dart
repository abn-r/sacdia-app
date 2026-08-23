import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_image_viewer.dart';
import '../../domain/entities/transaction.dart';
import '../providers/finances_providers.dart';
import 'add_transaction_sheet.dart';

/// Vista de detalle de un movimiento financiero.
///
/// Muestra todos los campos del movimiento y ofrece el botón de edición
/// cuando el mes está abierto y el usuario tiene permisos.
class TransactionDetailView extends ConsumerWidget {
  final FinanceTransaction transaction;

  const TransactionDetailView({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = transaction.type.isIncome;
    final color = isIncome ? AppColors.secondary : AppColors.error;
    final canManageAsync = ref.watch(canManageFinancesProvider);
    final financeMonthAsync = ref.watch(financeMonthProvider);
    final isOpen = financeMonthAsync.valueOrNull?.isOpen ?? true;
    final canEdit = (canManageAsync.valueOrNull ?? false) && isOpen;

    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        backgroundColor: context.sac.background,
        surfaceTintColor: Colors.transparent,
        title: Text('finances.transaction_detail.title'.tr()),
        actions: [
          if (canEdit) ...[
            IconButton(
              onPressed: () => _confirmDelete(context, ref),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedDelete01,
                size: 20,
                color: AppColors.error,
              ),
            ),
            IconButton(
              onPressed: () => _openEditSheet(context),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedPencilEdit01,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type + amount hero
            _AmountHero(transaction: transaction, color: color),

            const SizedBox(height: 20),

            // Details card
            _DetailCard(
              children: [
                _DetailRow(
                  icon: HugeIcons.strokeRoundedNote01,
                  label: 'finances.transaction_detail.concept'.tr(),
                  value: transaction.description,
                ),
                _divider(),
                _DetailRow(
                  icon: HugeIcons.strokeRoundedTag01,
                  label: 'finances.transaction_detail.category'.tr(),
                  value: transaction.category.name,
                ),
                _divider(),
                _DetailRow(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  label: 'finances.transaction_detail.date'.tr(),
                  value: DateFormat('dd \'de\' MMMM \'de\' yyyy', 'es')
                      .format(transaction.date.toLocal()),
                ),
                if (transaction.notes != null &&
                    transaction.notes!.isNotEmpty) ...[
                  _divider(),
                  _DetailRow(
                    icon: HugeIcons.strokeRoundedInformationCircle,
                    label: 'finances.transaction_detail.notes'.tr(),
                    value: transaction.notes!,
                    multiline: true,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            if (transaction.evidences.isNotEmpty) ...[
              _EvidenceCard(evidences: transaction.evidences),
              const SizedBox(height: 16),
            ],

            // Audit card
            _DetailCard(
              children: [
                _DetailRow(
                  icon: HugeIcons.strokeRoundedUser,
                  label: 'finances.transaction_detail.registered_by'.tr(),
                  value: transaction.registeredByName,
                ),
                _divider(),
                _DetailRow(
                  icon: HugeIcons.strokeRoundedClock01,
                  label: 'finances.transaction_detail.registration_date'.tr(),
                  value: DateFormat('dd/MM/yyyy HH:mm')
                      .format(transaction.registeredAt.toLocal()),
                ),
                if (transaction.modifiedByName != null) ...[
                  _divider(),
                  _DetailRow(
                    icon: HugeIcons.strokeRoundedPencilEdit01,
                    label: 'finances.transaction_detail.modified_by'.tr(),
                    value: transaction.modifiedByName!,
                  ),
                  if (transaction.modifiedAt != null) ...[
                    _divider(),
                    _DetailRow(
                      icon: HugeIcons.strokeRoundedClock01,
                      label:
                          'finances.transaction_detail.modification_date'.tr(),
                      value: DateFormat('dd/MM/yyyy HH:mm')
                          .format(transaction.modifiedAt!.toLocal()),
                    ),
                  ],
                ],
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _openEditSheet(BuildContext context) {
    showSacSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(existing: transaction),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'finances.transaction_detail.delete_dialog_title'.tr(),
      content: 'finances.transaction_detail.delete_dialog_content'.tr(),
      confirmLabel: 'common.delete'.tr(),
      confirmIsDestructive: true,
    );

    if (confirmed != true || !context.mounted) return;

    final notifier = ref.read(transactionFormNotifierProvider.notifier);
    final success = await notifier.delete(financeId: transaction.id);

    if (!context.mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('finances.transaction_detail.delete_success'.tr())),
      );
    } else {
      final error = ref.read(transactionFormNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(error ?? 'finances.transaction_detail.delete_error'.tr()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _divider() => const Divider(height: 1, thickness: 0.5);
}

// ── Amount hero ────────────────────────────────────────────────────────────────

class _AmountHero extends StatelessWidget {
  final FinanceTransaction transaction;
  final Color color;

  const _AmountHero({required this.transaction, required this.color});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type.isIncome;
    final formatted = NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    ).format(transaction.amount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: isIncome
                    ? HugeIcons.strokeRoundedArrowDown01
                    : HugeIcons.strokeRoundedArrowUp01,
                size: 28,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isIncome
                ? 'finances.transaction_detail.income'.tr()
                : 'finances.transaction_detail.expense'.tr(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatted,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Evidence card ─────────────────────────────────────────────────────────────

class _EvidenceCard extends StatelessWidget {
  final List<FinanceEvidence> evidences;

  const _EvidenceCard({required this.evidences});

  @override
  Widget build(BuildContext context) {
    final urls = evidences.map((e) => e.url).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: context.sac.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'finances.transaction_detail.evidence_title'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var index = 0; index < evidences.length; index++)
                _EvidenceThumb(
                  url: evidences[index].url,
                  onTap: () => SacImageViewer.show(
                    context,
                    imageUrl: evidences[index].url,
                    imageUrls: urls,
                    initialIndex: index,
                    title: 'finances.transaction_detail.evidence_title'.tr(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceThumb extends StatelessWidget {
  final String url;
  final VoidCallback onTap;

  const _EvidenceThumb({required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: context.sac.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              cacheWidth: 276,
              cacheHeight: 276,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Detail card ────────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final List<Widget> children;

  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: context.sac.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;
  final bool multiline;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          HugeIcon(
            icon: icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: multiline ? null : 2,
                  overflow: multiline ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
