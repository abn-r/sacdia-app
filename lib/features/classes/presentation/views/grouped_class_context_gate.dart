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
import '../widgets/grouped_class_skeleton.dart';

/// Gives [builder] the club and section of a grouped-class route. A link made
/// by the app carries them in the query; one opened from outside does not, so
/// they come from the active club context.
class GroupedClassContextGate extends ConsumerWidget {
  final int? clubId;
  final int? sectionId;
  final Widget Function(int clubId, int sectionId) builder;

  const GroupedClassContextGate({
    super.key,
    required this.clubId,
    required this.sectionId,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = clubId;
    final section = sectionId;
    if (club != null && section != null) return builder(club, section);

    final contextAsync = ref.watch(clubContextProvider);
    final clubContext = contextAsync.value;
    if (clubContext != null) {
      return builder(clubContext.clubId, clubContext.sectionId);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(title: 'classes.grouped.title'.tr(), frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            if (contextAsync.hasError) {
              return SacErrorState(
                title: 'classes.teaching_scope.context_error_title'.tr(),
                message: userErrorMessage(contextAsync.error),
                padding: SacTopBar.paddingBelowBar(
                  context,
                  const EdgeInsets.all(32),
                ),
                onRetry: () => ref.invalidate(clubContextProvider),
              );
            }
            if (contextAsync.isLoading) return const GroupedClassSkeleton();
            return Padding(
              padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
              child: SacEmptyState(
                icon: HugeIcons.strokeRoundedBuilding01,
                title: 'classes.teaching_scope.no_context_title'.tr(),
                body: 'classes.teaching_scope.no_context_body'.tr(),
              ),
            );
          },
        ),
      ),
    );
  }
}
