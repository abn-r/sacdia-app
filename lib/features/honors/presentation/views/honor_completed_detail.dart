import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/theme/honor_category_palette.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_action_bar.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_band_scaffold.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_history_cards.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_progress_band.dart';

/// Screen of a validated (APPROVED) honor.
///
/// The band shows the finished path with a full ring and a "Validada" badge;
/// "Resumen" celebrates and lists who validated it, "Mi trabajo" keeps the
/// history of what the member did. The sticky bar opens the profile, where
/// validated honors are listed (the credential does not show them).
class HonorCompletedDetail extends ConsumerWidget {
  const HonorCompletedDetail({
    super.key,
    required this.honor,
    required this.honorId,
    required this.userHonor,
    required this.categoryName,
  });

  final Honor honor;
  final int honorId;
  final UserHonor userHonor;
  final String? categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paintColor = getCategoryPaintColor(
      categoryId: honor.categoryId,
      categoryName: categoryName,
    );
    final bandColor = bandColorFor(
      categoryId: honor.categoryId,
      categoryName: categoryName,
    );
    final onTint = honorOnTint(context, bandColor);
    final modeLabel = completedModeLabel(userHonor);
    final validatedAt = userHonor.validatedAt;

    return HonorBandScaffold(
      bandColor: bandColor,
      paintColor: paintColor,
      honorName: honor.name,
      categoryName: categoryName,
      imageUrl: honor.imageUrl ?? userHonor.honorImageUrl,
      progress: 1,
      step: HonorWorkStep.validated,
      badge: SacBadge.success(
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        label: 'honors.detail.status_validated'.tr(),
      ),
      metaLabel: validatedAt == null
          ? modeLabel
          : 'honors.detail.completed_meta'.tr(namedArgs: {
              'date': SacDateFormatter.dateShort(validatedAt),
              'mode': modeLabel,
            }),
      tabLabels: [
        'honors.detail.tab_summary'.tr(),
        'honors.detail.tab_my_work'.tr(),
      ],
      tabBuilder: (context, tab) => tab == 0
          ? _SummaryTab(userHonor: userHonor)
          : _MyWorkTab(
              honorId: honorId,
              userHonor: userHonor,
              accent: onTint,
            ),
      bottomBar: HonorActionBar(
        child: SacButton.primary(
          key: const ValueKey('honor-profile-button'),
          text: 'honors.detail.view_profile_cta'.tr(),
          icon: HugeIcons.strokeRoundedUserCircle,
          backgroundColor: bandColor,
          textColor: Colors.white,
          onPressed: () => context.go(RouteNames.homeProfile),
        ),
      ),
    );
  }
}

/// Whether this approved honor predates work modes but carries external
/// evidence (format, images or certificate).
bool isExternalLegacyCompletedHonor(UserHonor userHonor) {
  if (!userHonor.isCompleted ||
      userHonor.completionMode != HonorCompletionMode.undecided) {
    return false;
  }

  return userHonor.hasCompletedFormat ||
      userHonor.images.isNotEmpty ||
      honorTrimmedOrNull(userHonor.certificate) != null;
}

/// Work mode as the history shows it, including rows that never chose one.
String completedModeLabel(UserHonor userHonor) {
  switch (userHonor.completionMode) {
    case HonorCompletionMode.inApp:
      return 'honors.detail.mode_in_app'.tr();
    case HonorCompletionMode.external:
      return 'honors.detail.mode_external'.tr();
    case HonorCompletionMode.undecided:
      return isExternalLegacyCompletedHonor(userHonor)
          ? 'honors.detail.mode_external_legacy'.tr()
          : 'honors.detail.mode_not_registered'.tr();
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.userHonor});

  final UserHonor userHonor;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacCard(
          key: const ValueKey('honor-celebration-card'),
          child: MergeSemantics(
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.successContainer,
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedAward01,
                      size: 28,
                      color: c.onSuccessContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'honors.detail.completed_title'.tr(),
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'honors.detail.completed_subtitle'.tr(),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        HonorValidationHistoryCard(userHonor: userHonor),
      ],
    );
  }
}

class _MyWorkTab extends ConsumerWidget {
  const _MyWorkTab({
    required this.honorId,
    required this.userHonor,
    required this.accent,
  });

  final int honorId;
  final UserHonor userHonor;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLegacyExternal = isExternalLegacyCompletedHonor(userHonor);
    final showExternalHistory =
        userHonor.hasCompletedFormat || userHonor.images.isNotEmpty;
    final showRequirementsHistory =
        userHonor.completionMode != HonorCompletionMode.external &&
            !isLegacyExternal;
    final progressAsync = showRequirementsHistory
        ? ref.watch(userHonorProgressProvider(honorId))
        : null;

    if (!showExternalHistory && !showRequirementsHistory) {
      return SacCard(
        child: SacEmptyState.inline(
          title: 'honors.detail.my_work_empty'.tr(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showExternalHistory)
          HonorExternalWorkHistoryCard(
            userHonor: userHonor,
            categoryColor: accent,
          ),
        if (showExternalHistory && showRequirementsHistory)
          const SizedBox(height: 12),
        if (showRequirementsHistory)
          HonorRequirementsHistoryCard(
            progressAsync: progressAsync!,
            categoryColor: accent,
          ),
      ],
    );
  }
}
