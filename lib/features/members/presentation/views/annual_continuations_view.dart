import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/annual_continuation.dart';
import '../providers/members_providers.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Lista de no inscritos del año vigente para la sección activa.
///
/// Acceso: `club_members:approve`.
/// GET/POST `/club-sections/{sectionId}/annual-continuations`
///
/// Scaffold propio para tests y rutas sueltas. En Miembros se embebe
/// [AnnualContinuationsBody] como tab.
class AnnualContinuationsView extends ConsumerWidget {
  const AnnualContinuationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(annualContinuationsNotifierProvider);
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: tr('members.continuations.title'),
          onBack: () => Navigator.of(context).maybePop(),
          titleIcon: HugeIcon(
            icon: HugeIcons.strokeRoundedUserCheck01,
            size: 22,
            color: SacAccent.of(context).color,
          ),
          actions: [
            if (asyncState.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: SacLoadingSmall(color: c.textTertiary),
                ),
              )
            else
              SacPressable(
                listenOnly: true,
                child: IconButton(
                  enableFeedback: false,
                  tooltip: 'common.refresh'.tr(),
                  onPressed: () =>
                      ref.invalidate(annualContinuationsNotifierProvider),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: c.textTertiary,
                    size: 18,
                  ),
                ),
              ),
          ],
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => const SafeArea(
            top: false,
            child: AnnualContinuationsBody(),
          ),
        ),
      ),
    );
  }
}

/// Cuerpo de continuaciones anuales, sin app bar. Tab de Miembros.
class AnnualContinuationsBody extends ConsumerWidget {
  const AnnualContinuationsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(annualContinuationsNotifierProvider);
    final hPad = Responsive.horizontalPadding(context);

    return asyncState.when(
      loading: () => const Center(child: SacLoading()),
      error: (error, _) => SacErrorState(
        title: tr('members.continuations.errors.fetch'),
        message: userErrorMessage(error),
        onRetry: () => ref.invalidate(annualContinuationsNotifierProvider),
      ),
      data: (state) {
        final items = state.items;
        if (items.isEmpty) {
          return SacEmptyState(
            icon: HugeIcons.strokeRoundedUserCheck01,
            title: tr('members.continuations.empty_title'),
            body: tr('members.continuations.empty_subtitle'),
          );
        }

        final period = state.periodLabel;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 4),
              child: Text(
                tr('members.continuations.subtitle'),
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  color: context.sac.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: SacTopBar.paddingBelowBar(
                    context, EdgeInsets.fromLTRB(hPad, 4, hPad, 100)),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = state.selectedIds.contains(item.userId);
                  return _ContinuationItem(
                    item: item,
                    isSelected: isSelected,
                    onToggle: item.isBlocked
                        ? null
                        : () => ref
                            .read(annualContinuationsNotifierProvider.notifier)
                            .toggleSelection(item.userId),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
              child: SacButton.primary(
                text: period == null
                    ? tr('members.continuations.submit_button_no_period')
                    : tr(
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
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final result =
        await ref.read(annualContinuationsNotifierProvider.notifier).submit();

    if (!context.mounted) return;

    if (result == null) {
      SacSnackBar.show(context, tr('members.continuations.errors.submit'),
          isError: true);
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

    SacSnackBar.show(context, message, isSuccess: !result.hasPartialFailure);
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
    // `current_role` llega como slug (`deputy-director`); se muestra traducido.
    final role = RoleUtils.translate((item.currentRole ?? '').trim());
    final blockedDetail = blocked ? _blockedLabel(item) : null;
    final metaParts = <String>[
      if (role.isNotEmpty)
        tr(
          'members.continuations.current_role',
          namedArgs: {'role': role},
        ),
      if (blockedDetail != null && blockedDetail.isNotEmpty) blockedDetail,
    ];

    return Semantics(
      label: item.name,
      checked: isSelected,
      child: SacPressable(
        onTap: onToggle,
        enabled: onToggle != null,
        child: Container(
          decoration: BoxDecoration(
            color: blocked
                ? c.surfaceVariant
                : isSelected
                    ? SacAccent.of(context).color.withValues(alpha: 0.06)
                    : c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            border: Border.all(
              color: blocked
                  ? c.border
                  : isSelected
                      ? SacAccent.of(context).color.withValues(alpha: 0.35)
                      : c.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: blocked
                      ? c.surfaceVariant
                      : isSelected
                          ? SacAccent.of(context).color
                          : c.surfaceVariant,
                  border: Border.all(
                    color: blocked
                        ? c.border
                        : isSelected
                            ? SacAccent.of(context).color
                            : c.border,
                  ),
                ),
                child: isSelected && !blocked
                    ? const HugeIcon(
                        icon: HugeIcons.strokeRoundedTick02,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        metaParts.join(' · '),
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          height: 1.2,
                          color: blocked ? c.textSecondary : c.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (blocked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  ),
                  child: Text(
                    tr('members.continuations.blocked'),
                    style: TextStyle(
                      fontSize: SacFontSize.labelSmall,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentDark,
                    ),
                  ),
                ),
            ],
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
