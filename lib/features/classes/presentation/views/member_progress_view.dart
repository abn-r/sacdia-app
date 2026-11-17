import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../providers/classes_providers.dart';
import '../widgets/grouped_class_skeleton.dart';
import '../widgets/grouped_member_body.dart';

/// One member's progress in a class, seen by the coach (director or
/// counselor). Not the member's own view: that is
/// `ClassDetailWithProgressView`.
/// Route: `/home/grouped-class/class/:classId/member/:userId`.
class MemberProgressView extends ConsumerWidget {
  final int classId;
  final String userId;
  final int? enrollmentId;

  /// Set by the list the coach came from. Without them (deep link) the
  /// counselor line of the subtitle is left out.
  final int? clubId;
  final int? sectionId;
  final int? yearId;
  final String? className;
  final String? memberName;

  const MemberProgressView({
    super.key,
    required this.classId,
    required this.userId,
    this.enrollmentId,
    this.clubId,
    this.sectionId,
    this.yearId,
    this.className,
    this.memberName,
  });

  ClassProgressQuery get _progressQuery => ClassProgressQuery(
        classId: classId,
        enrollmentId: enrollmentId,
        targetUserId: userId,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = _progressQuery;
    final progressAsync = ref.watch(classWithProgressProvider(query));

    // The members list already loaded gives the counselor and the name.
    final membersAsync = clubId != null && sectionId != null
        ? ref.watch(
            classMembersProgressProvider(
              ClassMembersProgressQuery(
                clubId: clubId!,
                sectionId: sectionId!,
                classId: classId,
                yearId: yearId,
              ),
            ),
          )
        : null;
    final members = membersAsync?.value;

    var name = memberName?.trim() ?? '';
    for (final m in members?.members ?? const []) {
      if (name.isEmpty && m.userId == userId) name = m.name;
    }
    final resolvedClassName = (className?.trim().isNotEmpty ?? false)
        ? className!.trim()
        : (progressAsync.value?.name ?? '');
    final counselor = members?.counselor?.name;
    final subtitle = resolvedClassName.isEmpty
        ? null
        : (members == null
            ? resolvedClassName
            : 'classes.grouped.member_subtitle'.tr(namedArgs: {
                'className': resolvedClassName,
                'counselor': (counselor == null || counselor.isEmpty)
                    ? 'classes.grouped.counselor_none'.tr()
                    : counselor,
              }));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: name.isEmpty ? 'classes.grouped.class_fallback'.tr() : name,
        subtitle: subtitle,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => progressAsync.when(
            loading: () => const GroupedClassSkeleton(rows: 5),
            error: (error, _) => SacErrorState(
              title: 'classes.grouped.member_load_error_title'.tr(),
              message: userErrorMessage(error),
              padding: SacTopBar.paddingBelowBar(
                context,
                const EdgeInsets.all(32),
              ),
              onRetry: () => ref.invalidate(classWithProgressProvider(query)),
            ),
            data: (progress) => GroupedMemberBody(
              progress: progress,
              onRefresh: () async {
                ref.invalidate(classWithProgressProvider(query));
                try {
                  await ref.read(classWithProgressProvider(query).future);
                } catch (_) {
                  // The error state of the provider already shows it.
                }
              },
              onOpenRequirement: (requirement) => context.push<void>(
                RouteNames.groupedClassRequirementPath(
                  classId,
                  userId,
                  requirement.id,
                  enrollmentId: enrollmentId,
                  clubId: clubId,
                  sectionId: sectionId,
                  yearId: yearId,
                  memberName: name,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
