import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../providers/classes_providers.dart';
import '../widgets/grouped_class_skeleton.dart';
import '../widgets/grouped_members_body.dart';

/// Members of one class and how far along each is, lowest progress first.
/// Route: `/home/grouped-class/class/:classId`.
class ClassMembersProgressView extends ConsumerStatefulWidget {
  final int clubId;
  final int sectionId;
  final int classId;

  /// Already known by the caller. When null (deep link) it is looked up in
  /// the scope of the section.
  final String? className;
  final int? yearId;

  const ClassMembersProgressView({
    super.key,
    required this.clubId,
    required this.sectionId,
    required this.classId,
    this.className,
    this.yearId,
  });

  @override
  ConsumerState<ClassMembersProgressView> createState() =>
      _ClassMembersProgressViewState();
}

class _ClassMembersProgressViewState
    extends ConsumerState<ClassMembersProgressView> {
  GroupedMembersFilter _filter = GroupedMembersFilter.all;

  ClassMembersProgressQuery get _query => ClassMembersProgressQuery(
        clubId: widget.clubId,
        sectionId: widget.sectionId,
        classId: widget.classId,
        yearId: widget.yearId,
      );

  String _resolveClassName() {
    final given = widget.className?.trim();
    if (given != null && given.isNotEmpty) return given;
    final scope = ref
        .watch(
          classProgressScopeProvider(
            TeachingScopeQuery(
              clubId: widget.clubId,
              sectionId: widget.sectionId,
              yearId: widget.yearId,
            ),
          ),
        )
        .value;
    for (final item in scope?.classes ?? const []) {
      if (item.classId == widget.classId) return item.name;
    }
    return 'classes.grouped.class_fallback'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final membersAsync = ref.watch(classMembersProgressProvider(query));
    final className = _resolveClassName();
    final clubTypeName = ref.watch(clubContextProvider).value?.clubTypeName;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: className,
        subtitle: clubTypeName,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => membersAsync.when(
            loading: () => const GroupedClassSkeleton(),
            error: (error, _) => SacErrorState(
              title: 'classes.grouped.load_error_title'.tr(),
              message: userErrorMessage(error),
              padding: SacTopBar.paddingBelowBar(
                context,
                const EdgeInsets.all(32),
              ),
              onRetry: () =>
                  ref.invalidate(classMembersProgressProvider(query)),
            ),
            data: (result) => GroupedMembersBody(
              result: result,
              className: className,
              filter: _filter,
              onFilterChanged: (filter) => setState(() => _filter = filter),
              onRefresh: () async {
                ref.invalidate(classMembersProgressProvider(query));
                try {
                  await ref.read(classMembersProgressProvider(query).future);
                } catch (_) {
                  // The error state of the provider already shows it.
                }
              },
              onOpenMember: (member) => context.push<void>(
                RouteNames.groupedClassMemberPath(
                  widget.classId,
                  member.userId,
                  clubId: widget.clubId,
                  sectionId: widget.sectionId,
                  enrollmentId: member.enrollmentId,
                  yearId: widget.yearId,
                  className: className,
                  memberName: member.name,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
