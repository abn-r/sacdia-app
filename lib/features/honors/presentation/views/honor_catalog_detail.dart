import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/theme/honor_category_palette.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_level_labels.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_action_bar.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_band_scaffold.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_catalog_info_tab.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_requirements_preview.dart';

/// Meta line under the name of a catalog honor: "Básico · General".
String honorLevelsMeta(Honor honor) {
  final skill = honor.skillLevel;
  return [
    if (skill != null) honorSkillLevelLabel(skill),
    honorApprovalLabel(honor.approval),
  ].join(' · ');
}

/// Screen of an honor the member has not joined yet.
///
/// The band has no ring and no step reached. "Requisitos" previews the
/// catalog requirement tree (read-only); "Información" holds the description,
/// material and how it works. The sticky bar enrolls.
class HonorCatalogDetail extends ConsumerWidget {
  const HonorCatalogDetail({
    super.key,
    required this.honor,
    required this.honorId,
    required this.categoryName,
    required this.userHonorsLoading,
    required this.enrollAsync,
  });

  final Honor honor;
  final int honorId;
  final String? categoryName;
  final bool userHonorsLoading;
  final AsyncValue<UserHonor?> enrollAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirementsAsync = ref.watch(honorRequirementsProvider(honorId));
    final paintColor = getCategoryPaintColor(
      categoryId: honor.categoryId,
      categoryName: categoryName,
    );
    final bandColor = bandColorFor(
      categoryId: honor.categoryId,
      categoryName: categoryName,
    );
    final onTint = honorOnTint(context, bandColor);
    final count = requirementsAsync.value?.length;

    return HonorBandScaffold(
      bandColor: bandColor,
      paintColor: paintColor,
      honorName: honor.name,
      categoryName: categoryName,
      imageUrl: honor.imageUrl,
      step: null,
      metaLabel: honorLevelsMeta(honor),
      tabLabels: [
        count == null
            ? 'honors.requirements.header_subtitle'.tr()
            : 'honors.catalog.tab_requirements'
                .tr(namedArgs: {'count': '$count'}),
        'honors.requirements.tab_info'.tr(),
      ],
      tabBuilder: (context, tab) => tab == 0
          ? HonorRequirementsPreview(
              requirements: requirementsAsync,
              onRetry: () => ref.invalidate(honorRequirementsProvider(honorId)),
            )
          : HonorCatalogInfoTab(
              honor: honor,
              paintColor: paintColor,
              chipForeground: onTint,
            ),
      bottomBar: _EnrollBar(
        honorId: honorId,
        bandColor: bandColor,
        userHonorsLoading: userHonorsLoading,
        enrollAsync: enrollAsync,
      ),
    );
  }
}

class _EnrollBar extends ConsumerWidget {
  const _EnrollBar({
    required this.honorId,
    required this.bandColor,
    required this.userHonorsLoading,
    required this.enrollAsync,
  });

  final int honorId;
  final Color bandColor;
  final bool userHonorsLoading;
  final AsyncValue<UserHonor?> enrollAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget enroll({bool loading = false}) => SacButton.primary(
          key: const ValueKey('honor-enroll-button'),
          text: 'honors.detail.enroll_cta'.tr(),
          backgroundColor: bandColor,
          textColor: Colors.white,
          isLoading: loading,
          onPressed: loading
              ? null
              : () async {
                  final userId = ref.read(authNotifierProvider).value?.id;
                  if (userId == null) return;
                  await ref
                      .read(honorEnrollmentNotifierProvider.notifier)
                      .enrollInHonor(userId, honorId);
                },
        );

    final Widget child;
    if (userHonorsLoading) {
      child = enroll(loading: true);
    } else {
      child = enrollAsync.when(
        data: (enrolled) =>
            enrolled != null ? const SizedBox.shrink() : enroll(),
        loading: () => enroll(loading: true),
        error: (err, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SacErrorState.inline(message: userErrorMessage(err)),
            ),
            enroll(),
          ],
        ),
      );
    }

    return HonorActionBar(child: child);
  }
}
