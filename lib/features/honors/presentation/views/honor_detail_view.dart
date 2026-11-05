import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_work_navigation.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_catalog_detail.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_completed_detail.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_mode_choice_detail.dart';

String _completionModeConfirmationMessageKey(HonorCompletionMode mode) {
  switch (mode) {
    case HonorCompletionMode.inApp:
      return 'honors.work_mode.confirm_in_app_message';
    case HonorCompletionMode.external:
      return 'honors.work_mode.confirm_external_message';
    case HonorCompletionMode.undecided:
      return 'honors.work_mode.confirm_message';
  }
}

/// Entry of `/honor/:id`: picks the screen that fits where the member is with
/// the honor.
///
/// - not enrolled: [HonorCatalogDetail]
/// - enrolled, work mode undecided: [HonorModeChoiceDetail]
/// - enrolled in app or external, not finished: redirects to the working
///   screen (`HonorRequirementsView` / `HonorEvidenceView`)
/// - APPROVED: [HonorCompletedDetail]
class HonorDetailView extends ConsumerWidget {
  final int honorId;
  final Honor? initialHonor;

  const HonorDetailView({
    super.key,
    required this.honorId,
    this.initialHonor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialHonor != null) {
      return _HonorDetailContent(honor: initialHonor!, honorId: honorId);
    }

    final honorAsync = ref.watch(honorByIdProvider(honorId));
    return honorAsync.when(
      data: (honor) {
        if (honor == null) {
          return _ErrorScaffold(
              onRetry: () => ref.invalidate(allHonorsProvider));
        }
        return _HonorDetailContent(honor: honor, honorId: honorId);
      },
      loading: () => const _LoadingScaffold(),
      error: (_, __) =>
          _ErrorScaffold(onRetry: () => ref.invalidate(allHonorsProvider)),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
          title: 'honors.catalog.title'.tr(),
          onBack: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).maybePop();
          },
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => Padding(
            padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
            child: const Center(child: SacLoading()),
          ),
        ),
      ),
    );
  }
}

// ── Error Scaffold ─────────────────────────────────────────────────────────────

class _ErrorScaffold extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorScaffold({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
          title: 'honors.catalog.title'.tr(),
          onBack: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).maybePop();
          },
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => Padding(
            padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
            child: SacErrorState(
              title: 'honors.detail.error_load'.tr(),
              retryLabel: 'honors.catalog.retry'.tr(),
              onRetry: onRetry,
            ),
          ),
        ),
      ),
    );
  }
}

class _HonorDetailContent extends ConsumerWidget {
  final Honor honor;
  final int honorId;

  const _HonorDetailContent({required this.honor, required this.honorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cachedUserHonor = ref.watch(userHonorForHonorProvider(honorId));
    final userHonorsLoading =
        ref.watch(userHonorsProvider.select((s) => s.isLoading));
    final enrollAsync = ref.watch(honorEnrollmentNotifierProvider);
    final modeActionState =
        ref.watch(honorCompletionModeActionsNotifierProvider);
    final modeActionUserHonor = modeActionState.value;
    final userHonor = modeActionUserHonor?.honorId == honorId
        ? modeActionUserHonor
        : cachedUserHonor;

    final categoryName = honor.categoryName ??
        ref.watch(categoryByIdProvider(honor.categoryId))?.name;

    // After enrollment, refresh providers so UI switches to enrolled state
    if (!userHonorsLoading &&
        enrollAsync.hasValue &&
        enrollAsync.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.invalidate(userHonorsProvider);
          ref.invalidate(userHonorForHonorProvider(honorId));
          ref.invalidate(honorEnrollmentNotifierProvider);
        }
      });
    }

    if (userHonor != null && userHonor.isCompleted) {
      return HonorCompletedDetail(
        honor: honor,
        honorId: honorId,
        userHonor: userHonor,
        categoryName: categoryName,
      );
    }

    if (userHonor != null &&
        userHonor.completionMode == HonorCompletionMode.undecided) {
      return HonorModeChoiceDetail(
        honor: honor,
        userHonor: userHonor,
        categoryName: categoryName,
        isLoading: modeActionState.isLoading,
        onSelectCompletionMode: (mode) =>
            _selectCompletionMode(context, ref, mode),
      );
    }

    if (userHonor == null) {
      return HonorCatalogDetail(
        honor: honor,
        honorId: honorId,
        categoryName: categoryName,
        userHonorsLoading: userHonorsLoading,
        enrollAsync: enrollAsync,
      );
    }

    // In app or external: the working screens own the flow.
    return _ResumeHonorWork(honor: honor, userHonor: userHonor);
  }

  Future<void> _selectCompletionMode(
    BuildContext context,
    WidgetRef ref,
    HonorCompletionMode mode,
  ) async {
    final confirmed = await _confirmCompletionModeSelection(context, mode);
    if (!confirmed || !context.mounted) return;

    final user = ref.read(authNotifierProvider).value ??
        await ref.read(authNotifierProvider.future);

    if (!context.mounted) return;

    final userId = user?.id;
    if (userId == null) {
      SacSnackBar.show(context, 'honors.detail.work_mode_no_session'.tr(),
          isError: true);
      return;
    }

    final success = await ref
        .read(honorCompletionModeActionsNotifierProvider.notifier)
        .updateCompletionMode(
          userId: userId,
          honorId: honorId,
          completionMode: mode,
        );

    if (!context.mounted) return;

    SacSnackBar.show(
      context,
      success
          ? 'honors.detail.work_mode_saved'.tr()
          : 'honors.detail.work_mode_error'.tr(),
      isError: !success,
    );
  }

  Future<bool> _confirmCompletionModeSelection(
    BuildContext context,
    HonorCompletionMode mode,
  ) async {
    // Choosing a work mode is a positive step, so it uses the success action
    // instead of the coral confirm button that reads as destructive.
    final result = await SacDialog.present<bool>(
      context,
      builder: (dialogContext) => SacDialog(
        title: 'honors.work_mode.confirm_title'.tr(),
        content: _completionModeConfirmationMessageKey(mode).tr(),
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        iconColor: AppColors.success,
        iconBackgroundColor: AppColors.success.withValues(alpha: 0.12),
        actions: [
          SacDialogAction(
            label: tr('core.dialog.cancel'),
            style: SacDialogActionStyle.cancel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          SacDialogAction(
            label: 'common.confirm'.tr(),
            style: SacDialogActionStyle.success,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}

class _ResumeHonorWork extends StatefulWidget {
  final Honor honor;
  final UserHonor userHonor;

  const _ResumeHonorWork({
    required this.honor,
    required this.userHonor,
  });

  @override
  State<_ResumeHonorWork> createState() => _ResumeHonorWorkState();
}

class _ResumeHonorWorkState extends State<_ResumeHonorWork> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      openEnrolledHonorWork(
        context,
        widget.userHonor,
        honorName: widget.honor.name,
        extraHonor: widget.honor,
        replace: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const _LoadingScaffold();
}
