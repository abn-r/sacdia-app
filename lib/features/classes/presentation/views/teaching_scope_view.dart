import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_back_button.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/progress_scope.dart';
import '../providers/classes_providers.dart';
import '../widgets/class_identity_badge.dart';
import 'class_counselor_assignments_view.dart';
import 'class_members_progress_view.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';

class TeachingScopeView extends ConsumerWidget {
  final int? yearId;

  const TeachingScopeView({
    super.key,
    this.yearId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubContextAsync = ref.watch(clubContextProvider);
    final activeClubContext = clubContextAsync.valueOrNull;
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final canReadAssignments = hasAnyPermission(user, const {
      'club_roles:read',
    });
    final canMutateAssignments = hasAnyPermission(user, const {
      'club_roles:assign',
      'club_roles:revoke',
    });
    final canManageAssignments = canReadAssignments && canMutateAssignments;
    final actionScopeQuery = activeClubContext == null
        ? null
        : TeachingScopeQuery(
            clubId: activeClubContext.clubId,
            sectionId: activeClubContext.sectionId,
            yearId: yearId,
          );
    final resolvedAssignmentYearId = actionScopeQuery == null
        ? yearId
        : ref
                .watch(classProgressScopeProvider(actionScopeQuery))
                .valueOrNull
                ?.ecclesiasticalYearId ??
            yearId;

    return Scaffold(
      backgroundColor: context.sac.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        title: Text('classes.teaching_scope.title'.tr()),
        actions: [
          if (canManageAssignments && activeClubContext != null)
            IconButton(
              tooltip: 'classes.class_assignments.title'.tr(),
              onPressed: resolvedAssignmentYearId == null
                  ? null
                  : () async {
                      final query = TeachingScopeQuery(
                        clubId: activeClubContext.clubId,
                        sectionId: activeClubContext.sectionId,
                        yearId: resolvedAssignmentYearId,
                      );
                      await Navigator.of(context).push(
                        SacSharedAxisRoute<void>(
                          builder: (_) => ClassCounselorAssignmentsView(
                            clubId: activeClubContext.clubId,
                            sectionId: activeClubContext.sectionId,
                            clubTypeId: activeClubContext.clubTypeId,
                            yearId: resolvedAssignmentYearId,
                          ),
                        ),
                      );
                      ref.invalidate(classProgressScopeProvider(query));
                    },
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedUserCheck01,
                size: 22,
                color: context.sac.ink700,
              ),
            ),
        ],
      ),
      body: clubContextAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => _MessageState(
          icon: HugeIcons.strokeRoundedAlert02,
          title: 'classes.teaching_scope.context_error_title'.tr(),
          message: error.toString().replaceFirst('Exception: ', ''),
        ),
        data: (clubContext) {
          if (clubContext == null) {
            return _MessageState(
              icon: HugeIcons.strokeRoundedBuilding01,
              title: 'classes.teaching_scope.no_context_title'.tr(),
              message: 'classes.teaching_scope.no_context_body'.tr(),
            );
          }

          final query = TeachingScopeQuery(
            clubId: clubContext.clubId,
            sectionId: clubContext.sectionId,
            yearId: yearId,
          );
          final scopeAsync = ref.watch(classProgressScopeProvider(query));

          return scopeAsync.when(
            loading: () => const Center(child: SacLoading()),
            error: (error, _) => _ErrorState(
              message: error.toString().replaceFirst('Exception: ', ''),
              onRetry: () => ref.invalidate(classProgressScopeProvider(query)),
            ),
            data: (scope) => _TeachingScopeBody(
              scope: scope,
              clubId: clubContext.clubId,
              sectionId: clubContext.sectionId,
              onRefresh: () async =>
                  ref.invalidate(classProgressScopeProvider(query)),
            ),
          );
        },
      ),
    );
  }
}

class _TeachingScopeBody extends StatelessWidget {
  final ProgressScopeResult scope;
  final int clubId;
  final int sectionId;
  final Future<void> Function() onRefresh;

  const _TeachingScopeBody({
    required this.scope,
    required this.clubId,
    required this.sectionId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (scope.classes.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 120),
            _MessageState(
              icon: HugeIcons.strokeRoundedBookOpen01,
              title: 'classes.teaching_scope.empty_title'.tr(),
              message: 'classes.teaching_scope.empty_body'.tr(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: scope.classes.length + 1,
        separatorBuilder: (_, index) =>
            index == 0 ? const SizedBox(height: 12) : const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const SizedBox();
          }

          final progressiveClass = scope.classes[index - 1];
          return _ClassScopeTile(
            progressiveClass: progressiveClass,
            onTap: () => Navigator.of(context).push(
              SacSharedAxisRoute<void>(
                builder: (_) => ClassMembersProgressView(
                  clubId: clubId,
                  sectionId: sectionId,
                  classId: progressiveClass.classId,
                  className: progressiveClass.name,
                  yearId: scope.ecclesiasticalYearId,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScopeHeader extends StatelessWidget {
  final ProgressScopeResult scope;

  const _ScopeHeader({required this.scope});

  @override
  Widget build(BuildContext context) {
    final isSectionScope = scope.hasSectionWideAccess;
    final title = isSectionScope
        ? 'classes.teaching_scope.section_scope_title'.tr()
        : 'classes.teaching_scope.assigned_scope_title'.tr();
    final body = isSectionScope
        ? 'classes.teaching_scope.section_scope_body'.tr()
        : 'classes.teaching_scope.assigned_scope_body'.tr();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedSchool,
                size: 22,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.sac.ink900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.sac.ink600,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassScopeTile extends StatelessWidget {
  final ProgressScopeClass progressiveClass;
  final VoidCallback onTap;

  const _ClassScopeTile({
    required this.progressiveClass,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final classColor = AppColors.classColor(progressiveClass.name);
    final c = context.sac;

    return Material(
      color: c.paper,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: classColor.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              ClassIdentityBadge(
                className: progressiveClass.name,
                fallbackIcon: HugeIcons.strokeRoundedBookOpen01,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progressiveClass.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: c.ink900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'classes.teaching_scope.open_members'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.ink500,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 20,
                color: classColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 52,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'classes.teaching_scope.load_error_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.sac.ink600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SacButton(
              text: 'common.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String message;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: icon,
              size: 54,
              color: context.sac.ink400,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.sac.ink600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
