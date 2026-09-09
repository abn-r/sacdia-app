import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../domain/entities/annual_continuation.dart';
import '../providers/members_providers.dart';

/// Lista de no inscritos del año vigente para la sección activa.
///
/// Acceso: `club_members:approve`.
/// GET/POST `/club-sections/{sectionId}/annual-continuations`
class AnnualContinuationsView extends ConsumerWidget {
  const AnnualContinuationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(annualContinuationsNotifierProvider);
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: tr('members.continuations.title'),
        onBack: () => Navigator.of(context).maybePop(),
        titleIcon: HugeIcon(
          icon: HugeIcons.strokeRoundedUserCheck01,
          size: 22,
          color: AppColors.primary,
        ),
        actions: [
          if (asyncState.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.textTertiary,
                ),
              ),
            )
          else
            IconButton(
              onPressed: () =>
                  ref.invalidate(annualContinuationsNotifierProvider),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                color: c.textTertiary,
                size: 18,
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: asyncState.when(
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => _ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(annualContinuationsNotifierProvider),
          ),
          data: (state) {
            final items = state.items;
            if (items.isEmpty) {
              return _EmptyView();
            }

            final period = state.periodLabel ?? '';

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 4),
                  child: Text(
                    tr('members.continuations.subtitle'),
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 100),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected =
                          state.selectedIds.contains(item.userId);
                      return _ContinuationItem(
                        item: item,
                        isSelected: isSelected,
                        onToggle: item.isBlocked
                            ? null
                            : () => ref
                                .read(annualContinuationsNotifierProvider
                                    .notifier)
                                .toggleSelection(item.userId),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
                  child: SacButton.primary(
                    text: tr(
                      'members.continuations.submit_button',
                      namedArgs: {'period': period},
                    ),
                    icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                    isEnabled: state.enrollableItems.isNotEmpty &&
                        state.selectedIds.isNotEmpty,
                    onPressed: () => _submit(context, ref),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(annualContinuationsNotifierProvider.notifier)
        .submit();

    if (!context.mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('members.continuations.errors.submit')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final enrolled = result.enrolledCount + result.alreadyEnrolledCount;
    final message = result.hasPartialFailure
        ? tr(
            'members.continuations.success_partial',
            namedArgs: {
              'enrolled': enrolled.toString(),
              'blocked': result.blockedCount.toString(),
              'failed': result.failedCount.toString(),
            },
          )
        : tr(
            'members.continuations.success',
            namedArgs: {'count': enrolled.toString()},
          );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: result.hasPartialFailure
            ? AppColors.accent
            : AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ContinuationItem extends StatelessWidget {
  final AnnualContinuation item;
  final bool isSelected;
  final VoidCallback? onToggle;

  const _ContinuationItem({
    required this.item,
    required this.isSelected,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final blocked = item.isBlocked;

    return Semantics(
      label: item.name,
      checked: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onToggle,
          child: Container(
            decoration: BoxDecoration(
              color: blocked
                  ? c.surfaceVariant
                  : isSelected
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: blocked
                    ? c.border
                    : isSelected
                        ? AppColors.primary.withValues(alpha: 0.35)
                        : c.border,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: blocked
                        ? c.surfaceVariant
                        : isSelected
                            ? AppColors.primary
                            : c.surfaceVariant,
                    border: Border.all(
                      color: blocked
                          ? c.border
                          : isSelected
                              ? AppColors.primary
                              : c.border,
                    ),
                  ),
                  child: isSelected && !blocked
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      if (item.currentRole != null &&
                          item.currentRole!.isNotEmpty)
                        Text(
                          tr(
                            'members.continuations.current_role',
                            namedArgs: {'role': item.currentRole!},
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textTertiary,
                          ),
                        ),
                      if (blocked)
                        Text(
                          _blockedLabel(item),
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (blocked)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tr('members.continuations.blocked'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentDark,
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

  String _blockedLabel(AnnualContinuation item) {
    final code = item.blockedReason ?? item.suggestedClass.code;
    if (code == null || code.isEmpty) {
      return tr('members.continuations.blocked');
    }
    final key = 'members.continuations.blocked_reasons.$code';
    final translated = tr(key);
    return translated == key ? code : translated;
  }
}

class _EmptyView extends StatelessWidget {
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
              icon: HugeIcons.strokeRoundedUserCheck01,
              size: 56,
              color: c.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              tr('members.continuations.empty_title'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              tr('members.continuations.empty_subtitle'),
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              tr('members.continuations.errors.fetch'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SacButton.primary(
              text: tr('common.retry'),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
