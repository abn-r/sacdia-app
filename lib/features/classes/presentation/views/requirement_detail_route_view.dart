import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../providers/classes_providers.dart';
import '../widgets/grouped_class_skeleton.dart';
import 'requirement_detail_view.dart';

/// Requirement of a member opened by id, so the route can be deep-linked:
/// `/home/grouped-class/class/:classId/member/:userId/requirement/:requirementId`.
/// It resolves the requirement from the member's progress and hands it to
/// [RequirementDetailView].
class RequirementDetailRouteView extends ConsumerWidget {
  final int classId;
  final String userId;
  final int requirementId;
  final int? enrollmentId;
  final String? memberName;

  const RequirementDetailRouteView({
    super.key,
    required this.classId,
    required this.userId,
    required this.requirementId,
    this.enrollmentId,
    this.memberName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ClassProgressQuery(
      classId: classId,
      enrollmentId: enrollmentId,
      targetUserId: userId,
    );
    final progressAsync = ref.watch(classWithProgressProvider(query));

    final progress = progressAsync.value;
    if (progress != null) {
      for (final requirement in progress.allRequirements) {
        if (requirement.id == requirementId) {
          return RequirementDetailView(
            requirement: requirement,
            classId: classId,
            enrollmentId: enrollmentId,
            targetUserId: userId,
            memberName: memberName,
          );
        }
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: 'classes.requirement_detail.title'.tr(),
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            final padding = SacTopBar.paddingBelowBar(
              context,
              const EdgeInsets.all(32),
            );
            if (progressAsync.hasError && progress == null) {
              return SacErrorState(
                title: 'classes.grouped.req.load_error_title'.tr(),
                message: userErrorMessage(progressAsync.error),
                padding: padding,
                onRetry: () => ref.invalidate(classWithProgressProvider(query)),
              );
            }
            if (progress == null) return const GroupedClassSkeleton(rows: 3);
            return Padding(
              padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
              child: SacEmptyState(
                key: const ValueKey('requirement-not-found'),
                icon: HugeIcons.strokeRoundedSearch01,
                title: 'classes.grouped.req.not_found_title'.tr(),
                body: 'classes.grouped.req.not_found_body'.tr(),
              ),
            );
          },
        ),
      ),
    );
  }
}
