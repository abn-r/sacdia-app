import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/utils/back_or_home.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../providers/classes_providers.dart';
import '../widgets/grouped_class_skeleton.dart';
import '../widgets/grouped_scope_body.dart';

/// Home of the grouped-class flow (`/home/grouped-class`): how every class in
/// scope is doing. The director sees the whole section; a counselor only the
/// classes assigned to them (the server decides, see `access_level`).
class TeachingScopeView extends ConsumerWidget {
  final int? yearId;

  const TeachingScopeView({super.key, this.yearId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubContextAsync = ref.watch(clubContextProvider);
    final clubContext = clubContextAsync.value;
    final user = ref.watch(authNotifierProvider).value;
    final canManageAssignments =
        hasAnyPermission(user, const {'club_roles:read'}) &&
            hasAnyPermission(
              user,
              const {'club_roles:assign', 'club_roles:revoke'},
            );

    TeachingScopeQuery? queryOf(ClubContext? ctx) => ctx == null
        ? null
        : TeachingScopeQuery(
            clubId: ctx.clubId,
            sectionId: ctx.sectionId,
            yearId: yearId,
          );

    final query = queryOf(clubContext);
    final resolvedYearId = query == null
        ? yearId
        : ref
                .watch(classProgressScopeProvider(query))
                .value
                ?.ecclesiasticalYearId ??
            yearId;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: 'classes.grouped.title'.tr(),
        frosted: true,
        onBack: () => backOrHome(context),
        actions: [
          if (canManageAssignments && query != null)
            SacPressable(
              listenOnly: true,
              child: IconButton(
                key: const ValueKey('grouped-assign-button'),
                enableFeedback: false,
                tooltip: 'classes.grouped.assign_tooltip'.tr(),
                onPressed: () async {
                  await context.push<void>(
                    RouteNames.groupedClassAssignPath(yearId: resolvedYearId),
                  );
                  // The assignments changed who the counselors are.
                  ref.invalidate(classProgressScopeProvider(query));
                },
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedUserAdd01,
                  size: 22,
                  color: context.sac.text,
                ),
              ),
            ),
        ],
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => clubContextAsync.when(
            loading: () => const GroupedClassSkeleton(),
            error: (error, _) => SacErrorState(
              title: 'classes.teaching_scope.context_error_title'.tr(),
              message: userErrorMessage(error),
              padding: SacTopBar.paddingBelowBar(
                context,
                const EdgeInsets.all(32),
              ),
              onRetry: () => ref.invalidate(clubContextProvider),
            ),
            data: (ctx) {
              if (ctx == null || query == null) {
                return Padding(
                  padding:
                      EdgeInsets.only(top: SacTopBar.frostedInset(context)),
                  child: SacEmptyState(
                    icon: HugeIcons.strokeRoundedBuilding01,
                    title: 'classes.teaching_scope.no_context_title'.tr(),
                    body: 'classes.teaching_scope.no_context_body'.tr(),
                  ),
                );
              }
              final scopeAsync = ref.watch(classProgressScopeProvider(query));
              return scopeAsync.when(
                loading: () => const GroupedClassSkeleton(),
                error: (error, _) => SacErrorState(
                  title: 'classes.grouped.load_error_title'.tr(),
                  message: userErrorMessage(error),
                  padding: SacTopBar.paddingBelowBar(
                    context,
                    const EdgeInsets.all(32),
                  ),
                  onRetry: () =>
                      ref.invalidate(classProgressScopeProvider(query)),
                ),
                data: (scope) => GroupedScopeBody(
                  scope: scope,
                  clubTypeName: ctx.clubTypeName,
                  onRefresh: () async {
                    ref.invalidate(classProgressScopeProvider(query));
                    try {
                      await ref.read(classProgressScopeProvider(query).future);
                    } catch (_) {
                      // The error state of the provider already shows it.
                    }
                  },
                  onOpenClass: (item) => context.push<void>(
                    RouteNames.groupedClassClassPath(
                      item.classId,
                      clubId: ctx.clubId,
                      sectionId: ctx.sectionId,
                      yearId: scope.ecclesiasticalYearId,
                      className: item.name,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
