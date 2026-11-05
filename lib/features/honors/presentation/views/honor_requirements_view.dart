import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/theme/honor_category_palette.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_submission_readiness.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_abandon_menu_button.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_band_scaffold.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_progress_band.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_rejection_card.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_requirement_row.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_requirement_group_view.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_submit_bar.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_work_info_tab.dart';
import 'package:sacdia_app/features/validation/domain/entities/validation.dart';
import 'package:sacdia_app/features/validation/presentation/providers/validation_providers.dart'
    show submitValidationProvider;

/// In-progress screen of an honor worked inside the app.
///
/// A colored band (patch, progress ring, four-step path) over two tabs:
/// "Requisitos" lists the top-level requirements as compact rows (each opens
/// a sheet that owns its edits) and "Información" holds the completion date,
/// instructor, material and levels. A sticky bar sends the honor to review
/// once [computeHonorSubmissionReadiness] says it can go.
class HonorRequirementsView extends ConsumerStatefulWidget {
  final int honorId;
  final int userHonorId;
  final String honorName;

  const HonorRequirementsView({
    super.key,
    required this.honorId,
    required this.userHonorId,
    required this.honorName,
  });

  @override
  ConsumerState<HonorRequirementsView> createState() =>
      _HonorRequirementsViewState();
}

class _HonorRequirementsViewState extends ConsumerState<HonorRequirementsView> {
  Future<void> _submit(UserHonor userHonor) async {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(submitValidationProvider.notifier);
    final success = await notifier.submit(
      entityType: ValidationEntityType.honor,
      entityId: userHonor.id, // user_honor_id, NOT honor_id
    );
    if (!mounted) return;
    if (success) {
      // The band moves to "En revisión" when the list reloads.
      ref.invalidate(userHonorsProvider);
      ref.invalidate(userHonorForHonorProvider(widget.honorId));
      SacSnackBar.show(
        context,
        'honors.evidence.sent_review'.tr(),
        isSuccess: true,
      );
    } else {
      final state = ref.read(submitValidationProvider);
      SacSnackBar.show(
        context,
        userErrorMessage(state.failure ?? state.errorMessage),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requirementsAsync =
        ref.watch(honorRequirementsProvider(widget.honorId));
    final progressAsync = ref.watch(userHonorProgressProvider(widget.honorId));
    final userHonorsAsync = ref.watch(userHonorsProvider);
    final userHonor = ref.watch(userHonorForHonorProvider(widget.honorId));
    final isSubmitting =
        ref.watch(submitValidationProvider.select((s) => s.isLoading));

    final honor = ref
        .watch(allHonorsProvider)
        .value
        ?.where((h) => h.id == widget.honorId)
        .firstOrNull;
    final categoryId = honor?.categoryId ?? userHonor?.honorCategoryId;
    final categoryName = honor?.categoryName ??
        userHonor?.honorCategoryName ??
        (categoryId != null
            ? ref.watch(categoryByIdProvider(categoryId))?.name
            : null);
    final paintColor = getCategoryPaintColor(
      categoryId: categoryId,
      categoryName: categoryName,
    );
    final bandColor = bandColorFor(
      categoryId: categoryId,
      categoryName: categoryName,
    );

    if (userHonor == null) {
      if (userHonorsAsync.isLoading) {
        return _StateScaffold(
          honorName: widget.honorName,
          child: const _LoadingBody(),
        );
      }
      return _ModeGuardScaffold(
        honorName: widget.honorName,
        categoryColor: paintColor,
        title: 'honors.requirements.mode_guard_title'.tr(),
        message: 'honors.requirements.mode_guard_not_found'.tr(),
      );
    }

    if (userHonor.completionMode != HonorCompletionMode.inApp) {
      return _ModeGuardScaffold(
        honorName: widget.honorName,
        categoryColor: paintColor,
        title: 'honors.requirements.mode_guard_title'.tr(),
        message: userHonor.completionMode == HonorCompletionMode.external
            ? 'honors.requirements.mode_guard_external'.tr()
            : 'honors.requirements.mode_guard_undecided'.tr(),
      );
    }

    // Keep showing the last data while a reload runs (a save or a submit
    // invalidates the providers); only a first load shows the skeleton.
    final requirements = requirementsAsync.value;
    final progress = progressAsync.value;
    if (requirements == null || progress == null) {
      final error = requirementsAsync.hasError
          ? requirementsAsync.error
          : (progressAsync.hasError ? progressAsync.error : null);
      if (error != null) {
        return _StateScaffold(
          honorName: widget.honorName,
          child: SacErrorState(
            scrollable: true,
            retryLabel: 'honors.requirements.retry'.tr(),
            title: userErrorMessage(error),
            onRetry: () {
              ref.invalidate(honorRequirementsProvider(widget.honorId));
              ref.invalidate(userHonorProgressProvider(widget.honorId));
            },
          ),
        );
      }
      return _StateScaffold(
        honorName: widget.honorName,
        child: const _LoadingBody(),
      );
    }

    final readiness = computeHonorSubmissionReadiness(
      requirements: requirements,
      progress: progress,
      completedAt: userHonor.completedAt,
      mode: userHonor.completionMode,
    );

    final onTint = honorOnTint(context, bandColor);
    final name = (honor?.name.isNotEmpty ?? false)
        ? honor!.name
        : (userHonor.honorName ?? widget.honorName);
    final percent = (readiness.fraction * 100).round();
    final rejected = userHonor.validationStatus.toUpperCase() == 'REJECTED';

    return HonorBandScaffold(
      bandColor: bandColor,
      paintColor: paintColor,
      honorName: name,
      categoryName: categoryName,
      imageUrl: honor?.imageUrl ?? userHonor.honorImageUrl,
      progress: readiness.fraction,
      metaLabel: 'honors.requirements.band_meta'.tr(
        namedArgs: {
          'percent': '$percent',
          'mode': 'honors.detail.mode_in_app'.tr(),
        },
      ),
      step: honorWorkStepFor(userHonor),
      actions: [
        HonorAbandonMenuButton(
          userHonor: userHonor,
          honorName: name,
          progressSummary: readiness.doneCount == 0
              ? null
              : 'honors.abandon.progress_in_app'.tr(namedArgs: {
                  'done': '${readiness.doneCount}',
                  'total': '${readiness.totalCount}',
                  'percent': '$percent',
                }),
        ),
      ],
      tabLabels: [
        'honors.requirements.tab_requirements'.tr(
          namedArgs: {
            'done': '${readiness.doneCount}',
            'total': '${readiness.totalCount}',
          },
        ),
        'honors.requirements.tab_info'.tr(),
      ],
      tabBuilder: (context, tab) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rejected) ...[
            HonorRejectionCard(reason: userHonor.rejectionReason),
            const SizedBox(height: 12),
          ],
          if (tab == 0)
            _RequirementsList(
              readiness: readiness,
              paintColor: paintColor,
              onOpen: (item) => openHonorRequirement(
                context,
                honorId: widget.honorId,
                honorName: name,
                requirement: item.requirement,
                paintColor: paintColor,
                bandColor: bandColor,
                enabled: userHonor.canSubmit,
              ),
            )
          else
            HonorWorkInfoTab(
              userHonor: userHonor,
              honorId: widget.honorId,
              honor: honor,
              paintColor: paintColor,
              chipForeground: onTint,
            ),
        ],
      ),
      bottomBar: userHonor.isCompleted
          ? null
          : HonorSubmitBar(
              summary: HonorSubmitBar.summaryFor(readiness),
              canSubmit: readiness.canSubmit,
              bandColor: bandColor,
              isUnderReview: userHonor.isUnderReview,
              isSubmitting: isSubmitting,
              onSubmit: () => _submit(userHonor),
            ),
    );
  }
}

class _RequirementsList extends StatelessWidget {
  const _RequirementsList({
    required this.readiness,
    required this.paintColor,
    required this.onOpen,
  });

  final HonorSubmissionReadiness readiness;
  final Color paintColor;
  final ValueChanged<RequirementReadiness> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    if (readiness.items.isEmpty) {
      return SacCard(
        child: SacEmptyState.inline(
          title: 'honors.requirements.empty'.tr(),
        ),
      );
    }
    return SacCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < readiness.items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.borderLight),
            HonorRequirementRow(
              key: ValueKey(
                  'requirement-row-${readiness.items[i].requirement.id}'),
              readiness: readiness.items[i],
              paintColor: paintColor,
              onTap: () => onOpen(readiness.items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Plain scaffold (regular top bar) for the loading and error states, where
/// the colored band does not exist yet.
class _StateScaffold extends StatelessWidget {
  const _StateScaffold({required this.honorName, required this.child});

  final String honorName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: honorName,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: child,
    );
  }
}

class _ModeGuardScaffold extends StatelessWidget {
  final String honorName;
  final Color categoryColor;
  final String title;
  final String message;

  const _ModeGuardScaffold({
    required this.honorName,
    required this.categoryColor,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
          title: honorName,
          onBack: () => Navigator.of(context).maybePop(),
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => Padding(
            padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedRoute01,
                    size: 48,
                    color: categoryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.sac.text,
                      fontSize: SacFontSize.headlineSmall,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.sac.textSecondary,
                      fontSize: SacFontSize.titleSmall,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SacButton.outline(
                    text: 'honors.requirements.mode_guard_back'.tr(),
                    textColor: categoryColor,
                    borderColor: categoryColor,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton of the band and the requirement rows.
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: SacShimmer(
              child: Container(
                color: context.sac.skeleton,
                padding: const EdgeInsets.fromLTRB(
                  kHonorPagePadding,
                  20,
                  kHonorPagePadding,
                  34,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SacSkeletonBox(
                          width: 84,
                          height: 84,
                          radius: AppTheme.radiusFull,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SacSkeletonBox(
                                width: 90,
                                height: 12,
                                radius: AppTheme.radius2XS,
                              ),
                              SizedBox(height: 8),
                              SacSkeletonBox(height: 20),
                              SizedBox(height: 8),
                              SacSkeletonBox(width: 120, height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const SacSkeletonBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
          const SacSkeletonList(
            itemCount: 5,
            scrollable: false,
            padding: EdgeInsets.fromLTRB(
                kHonorPagePadding, 24, kHonorPagePadding, 24),
          ),
        ],
      ),
    );
  }
}
