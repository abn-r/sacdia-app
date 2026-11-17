import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/progress_scope.dart';
import '../providers/classes_providers.dart';
import '../widgets/grouped_class_skeleton.dart';
import 'class_counselor_assignments_view.dart';

/// Route entry of the counselors screen (`/home/grouped-class/assign`): it
/// takes the club and section from the active context and, when the link has
/// no year, the year of the section's scope.
class GroupedClassAssignRouteView extends ConsumerWidget {
  final int? yearId;

  const GroupedClassAssignRouteView({super.key, this.yearId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(clubContextProvider);
    final clubContext = contextAsync.value;

    int? resolvedYearId = yearId;
    AsyncValue<ProgressScopeResult>? scopeAsync;
    TeachingScopeQuery? scopeQuery;
    if (clubContext != null && resolvedYearId == null) {
      scopeQuery = TeachingScopeQuery(
        clubId: clubContext.clubId,
        sectionId: clubContext.sectionId,
      );
      scopeAsync = ref.watch(classProgressScopeProvider(scopeQuery));
      resolvedYearId = scopeAsync?.value?.ecclesiasticalYearId;
    }

    if (clubContext != null && resolvedYearId != null) {
      return ClassCounselorAssignmentsView(
        clubId: clubContext.clubId,
        sectionId: clubContext.sectionId,
        clubTypeId: clubContext.clubTypeId,
        yearId: resolvedYearId,
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: 'classes.grouped.assign.title'.tr(),
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            final padding = SacTopBar.paddingBelowBar(
              context,
              const EdgeInsets.all(32),
            );
            if (scopeAsync != null && scopeAsync.hasError) {
              return SacErrorState(
                title: 'classes.grouped.load_error_title'.tr(),
                message: userErrorMessage(scopeAsync.error),
                padding: padding,
                onRetry: () =>
                    ref.invalidate(classProgressScopeProvider(scopeQuery!)),
              );
            }
            if (contextAsync.hasError) {
              return SacErrorState(
                title: 'classes.teaching_scope.context_error_title'.tr(),
                message: userErrorMessage(contextAsync.error),
                padding: padding,
                onRetry: () => ref.invalidate(clubContextProvider),
              );
            }
            if (!contextAsync.isLoading && clubContext == null) {
              return Padding(
                padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
                child: SacEmptyState(
                  icon: HugeIcons.strokeRoundedBuilding01,
                  title: 'classes.teaching_scope.no_context_title'.tr(),
                  body: 'classes.teaching_scope.no_context_body'.tr(),
                ),
              );
            }
            return const GroupedClassSkeleton(rows: 6);
          },
        ),
      ),
    );
  }
}
