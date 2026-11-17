import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/domain/entities/club_member.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/progressive_class.dart';
import '../providers/classes_providers.dart';
import '../utils/assignable_responsible.dart';
import '../utils/counselor_rows.dart';
import '../widgets/counselor_assignment_sheet.dart';
import '../widgets/counselor_class_row.dart';
import '../widgets/grouped_class_skeleton.dart';

/// Counselor and sub-counselor of each class of the section. Only the
/// director reaches it (gear of the grouped-class home).
/// Route: `/home/grouped-class/assign`.
class ClassCounselorAssignmentsView extends ConsumerWidget {
  final int clubId;
  final int sectionId;
  final int? clubTypeId;
  final int? yearId;

  const ClassCounselorAssignmentsView({
    super.key,
    required this.clubId,
    required this.sectionId,
    this.clubTypeId,
    this.yearId,
  });

  ClassCounselorAssignmentsQuery get _query => ClassCounselorAssignmentsQuery(
        clubId: clubId,
        sectionId: sectionId,
        yearId: yearId,
        active: true,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = _query;
    final assignmentsAsync =
        ref.watch(classCounselorAssignmentsProvider(query));
    final classesAsync = clubTypeId == null
        ? null
        : ref.watch(classesByClubTypeProvider(clubTypeId!));
    final membersAsync = ref.watch(membersNotifierProvider);
    final user = ref.watch(authNotifierProvider).value;
    final canAssign = hasAnyPermission(user, const {'club_roles:assign'});
    final canRevoke = hasAnyPermission(user, const {'club_roles:revoke'});
    final clubTypeName = ref.watch(clubContextProvider).value?.clubTypeName;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: 'classes.grouped.assign.title'.tr(),
        subtitle: clubTypeName,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => assignmentsAsync.when(
            loading: () => const GroupedClassSkeleton(rows: 6),
            error: (error, _) => SacErrorState(
              title: 'classes.class_assignments.load_error_title'.tr(),
              message: userErrorMessage(error),
              padding: SacTopBar.paddingBelowBar(
                context,
                const EdgeInsets.all(32),
              ),
              onRetry: () =>
                  ref.invalidate(classCounselorAssignmentsProvider(query)),
            ),
            data: (assignments) {
              if (classesAsync != null && classesAsync.isLoading) {
                return const GroupedClassSkeleton(rows: 6);
              }
              final rows = buildCounselorRows(
                classesAsync?.value ?? const <ProgressiveClass>[],
                assignments,
              );
              return RefreshIndicator(
                edgeOffset: SacTopBar.frostedInset(context),
                onRefresh: () async {
                  ref.invalidate(classCounselorAssignmentsProvider(query));
                  ref.invalidate(membersNotifierProvider);
                  if (clubTypeId != null) {
                    ref.invalidate(classesByClubTypeProvider(clubTypeId!));
                  }
                },
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(height: SacTopBar.frostedInset(context)),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Text(
                          'classes.grouped.assign.intro'.tr(),
                          style: TextStyle(
                            fontSize: SacFontSize.bodyMedium,
                            height: 1.45,
                            color: context.sac.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SacGroupedSection(
                        key: const ValueKey('counselor-classes'),
                        label: 'classes.grouped.assign.classes'.tr(),
                        children: [
                          for (final row in rows)
                            CounselorClassRow(
                              row: row,
                              isEditable: canAssign || canRevoke,
                              onTap: () => _openSheet(
                                context,
                                row,
                                membersAsync: membersAsync,
                                canAssign: canAssign,
                                canRevoke: canRevoke,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    ClassCounselorRow row, {
    required AsyncValue<MembersData> membersAsync,
    required bool canAssign,
    required bool canRevoke,
  }) async {
    final candidates = (membersAsync.value?.members ?? const <ClubMember>[])
        .where(isAssignableResponsible)
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    // Without people to choose from there is nothing to pick, but the current
    // ones can still be removed.
    if (canAssign && candidates.isEmpty && !row.hasAnyAssignment) {
      final message = membersAsync.isLoading
          ? 'classes.class_assignments.loading_catalog'.tr()
          : membersAsync.hasError
              ? 'classes.class_assignments.catalog_error'.tr()
              : 'classes.class_assignments.no_candidates'.tr();
      SacSnackBar.show(context, message, isError: !membersAsync.isLoading);
      return;
    }

    final outcome = await showSacSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.sac.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (_) => CounselorAssignmentSheet(
        query: _query,
        row: row,
        candidates: candidates,
        canAssign: canAssign,
        canRevoke: canRevoke,
      ),
    );

    final message = assignmentOutcomeMessage(outcome);
    if (message != null && context.mounted) {
      SacSnackBar.show(context, message, isSuccess: true);
    }
  }
}
