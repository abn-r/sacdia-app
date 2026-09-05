import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_back_button.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/class_members_progress.dart';
import '../providers/classes_providers.dart';
import '../widgets/class_identity_badge.dart';
import 'class_detail_with_progress_view.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';

class ClassMembersProgressView extends ConsumerWidget {
  final int clubId;
  final int sectionId;
  final int classId;
  final String className;
  final int? yearId;

  const ClassMembersProgressView({
    super.key,
    required this.clubId,
    required this.sectionId,
    required this.classId,
    required this.className,
    this.yearId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ClassMembersProgressQuery(
      clubId: clubId,
      sectionId: sectionId,
      classId: classId,
      yearId: yearId,
    );
    final membersAsync = ref.watch(classMembersProgressProvider(query));

    return Scaffold(
      backgroundColor: context.sac.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        title: Text(className),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => _ErrorState(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(classMembersProgressProvider(query)),
        ),
        data: (result) => _MembersBody(
          result: result,
          className: className,
          onRefresh: () async =>
              ref.invalidate(classMembersProgressProvider(query)),
        ),
      ),
    );
  }
}

class _MembersBody extends StatelessWidget {
  final ClassMembersProgressResult result;
  final String className;
  final Future<void> Function() onRefresh;

  const _MembersBody({
    required this.result,
    required this.className,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final classColor = AppColors.classColor(className);

    if (result.members.isEmpty) {
      return RefreshIndicator(
        color: classColor,
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 120),
            _MessageState(
              icon: HugeIcons.strokeRoundedUserGroup,
              title: 'classes.members_progress.empty_title'.tr(),
              message: 'classes.members_progress.empty_body'.tr(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: classColor,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: result.members.length + 1,
        separatorBuilder: (_, index) =>
            index == 0 ? const SizedBox(height: 12) : const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _MembersHeader(
              className: className,
              count: result.members.length,
              classColor: classColor,
            );
          }

          final member = result.members[index - 1];
          return _MemberProgressTile(
            member: member,
            classColor: classColor,
            onTap: () => Navigator.of(context).push(
              SacSharedAxisRoute<void>(
                builder: (_) => ClassDetailWithProgressView(
                  classId: member.classId,
                  enrollmentId: member.enrollmentId,
                  targetUserId: member.userId,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MembersHeader extends StatelessWidget {
  final String className;
  final int count;
  final Color classColor;

  const _MembersHeader({
    required this.className,
    required this.count,
    required this.classColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: classColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          ClassIdentityBadge(
            className: className,
            size: 44,
            fallbackIcon: HugeIcons.strokeRoundedUserGroup,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: c.ink900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'classes.members_progress.member_count'
                      .tr(namedArgs: {'count': count.toString()}),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.ink600,
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

class _MemberProgressTile extends StatelessWidget {
  final ClassMemberProgress member;
  final Color classColor;
  final VoidCallback onTap;

  const _MemberProgressTile({
    required this.member,
    required this.classColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = member.overallProgress.clamp(0, 100);
    final completedLabel =
        '${member.completedSections}/${member.totalSections}';
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
            border: Border.all(color: c.ink150),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: classColor.withValues(alpha: 0.12),
                    child: Text(
                      _initials(member.name),
                      style: TextStyle(
                        color: classColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name.isEmpty ? member.userId : member.name,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: c.ink900,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'classes.members_progress.completed_sections'
                              .tr(namedArgs: {'value': completedLabel}),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: c.ink500,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$safeProgress%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: classColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: safeProgress / 100,
                  backgroundColor: c.ink100,
                  color: classColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts.last.characters.first : '';
    return '$first$second'.toUpperCase();
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
              'classes.members_progress.load_error_title'.tr(),
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
