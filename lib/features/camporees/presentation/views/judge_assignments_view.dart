import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_judge_assignment.dart';

import '../providers/camporees_providers.dart';

/// Lista de asignaciones donde el usuario actual es juez principal.
class JudgeAssignmentsView extends ConsumerWidget {
  const JudgeAssignmentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(camporeeJudgeAssignmentsProvider);

    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: AppBar(
        backgroundColor: context.sac.background,
        foregroundColor: context.sac.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const SacBackButton(),
        title: Text('camporees.judge.assignments_title'.tr()),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(camporeeJudgeAssignmentsProvider);
          },
          child: assignmentsAsync.when(
            data: (assignments) {
              final primaryAssignments = assignments
                  .where((assignment) => assignment.canCaptureOfficialScore)
                  .toList();

              if (primaryAssignments.isEmpty) {
                return _EmptyAssignments(onRetry: () {
                  ref.invalidate(camporeeJudgeAssignmentsProvider);
                });
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemBuilder: (context, index) => _AssignmentTile(
                  assignment: primaryAssignments[index],
                ),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: primaryAssignments.length,
              );
            },
            loading: () => const Center(child: SacLoading()),
            error: (error, _) => _ErrorAssignments(
              message: error.toString().replaceFirst('Exception: ', ''),
              onRetry: () => ref.invalidate(camporeeJudgeAssignmentsProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  final CamporeeJudgeAssignment assignment;

  const _AssignmentTile({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final eventTitle = assignment.eventTitle?.trim().isNotEmpty == true
        ? assignment.eventTitle!
        : 'camporees.judge.event_fallback'.tr(
            namedArgs: {'eventId': '${assignment.eventId}'},
          );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eventTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'camporees.judge.section_label'.tr(
              namedArgs: {'sectionId': '${assignment.clubSectionId}'},
            ),
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SacButton.primary(
            text: 'camporees.judge.score_action'.tr(),
            icon: HugeIcons.strokeRoundedNoteEdit,
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push(
                RouteNames.camporeeJudgeScoreEntryPath(
                  assignment.eventId,
                  assignment.clubSectionId,
                  eventTitle: eventTitle,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyAssignments extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyAssignments({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 96),
        HugeIcon(
          icon: HugeIcons.strokeRoundedCheckList,
          size: 52,
          color: context.sac.textTertiary,
        ),
        const SizedBox(height: 16),
        Text(
          'camporees.judge.no_primary_assignments'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.sac.text,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'camporees.judge.no_primary_assignments_hint'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.sac.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 20),
        SacButton.outline(
          text: 'common.retry'.tr(),
          icon: HugeIcons.strokeRoundedRefresh,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _ErrorAssignments extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorAssignments({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: context.sac.error,
            ),
            const SizedBox(height: 12),
            Text(
              'camporees.judge.assignments_error'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.sac.text,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.sac.textSecondary),
            ),
            const SizedBox(height: 20),
            SacButton.primary(
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
