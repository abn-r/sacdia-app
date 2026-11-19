import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/activity.dart';
import '../providers/activities_providers.dart';
import '../widgets/activity_attendees_section.dart';
import '../widgets/activity_audience_line.dart';
import '../widgets/activity_date_format.dart';
import '../widgets/activity_date_tile.dart';
import '../widgets/activity_description_block.dart';
import '../widgets/activity_detail_actions.dart';
import '../widgets/activity_detail_row.dart';
import '../widgets/activity_detail_skeleton.dart';
import '../widgets/activity_map_card.dart';
import '../widgets/activity_more_sheet.dart';
import '../widgets/activity_state_panel.dart';
import '../widgets/activity_type_style.dart';
import '../widgets/activity_virtual_attendance.dart';
import 'activity_attendance_view.dart';
import 'activity_manual_attendance_view.dart';
import 'activity_my_qr_view.dart';
import 'edit_activity_view.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';

/// Activity detail screen.
///
/// Layout: standard top bar (back, "⋯" with Edit / Delete) → header (date
/// tile, name, type chip) → map card (in-person / hybrid) → state panel
/// (countdown, in progress, finished) → DETAILS → description → attendance →
/// organizer, with one primary action in a frosted footer.
class ActivityDetailView extends ConsumerStatefulWidget {
  final int activityId;

  /// Replaces the Google map in tests (a real one needs a platform view).
  final ActivityMapBuilder? mapBuilder;

  const ActivityDetailView({
    super.key,
    required this.activityId,
    this.mapBuilder,
  });

  @override
  ConsumerState<ActivityDetailView> createState() => _ActivityDetailViewState();
}

class _ActivityDetailViewState extends ConsumerState<ActivityDetailView> {
  // ── navigation ──────────────────────────────────────────────────────────────

  Future<void> _navigateToEdit(Activity activity) async {
    final result = await Navigator.push<bool>(
      context,
      SacSharedAxisRoute(builder: (_) => EditActivityView(activity: activity)),
    );
    if (result == true && mounted) {
      ref.invalidate(activityDetailProvider(widget.activityId));
    }
  }

  Future<void> _openMoreSheet(
    Activity activity, {
    required bool canEdit,
    required bool canDelete,
  }) async {
    final action = await showActivityMoreSheet(
      context,
      canEdit: canEdit,
      canDelete: canDelete,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ActivityMoreAction.edit:
        await _navigateToEdit(activity);
      case ActivityMoreAction.delete:
        await _confirmDelete();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await SacDialog.show(
      context,
      title: 'activities.detail.delete_title'.tr(),
      content: 'activities.detail.delete_confirm'.tr(),
      confirmLabel: 'activities.detail.delete_button'.tr(),
      confirmIsDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final success = await ref
        .read(deleteActivityNotifierProvider.notifier)
        .delete(widget.activityId);

    if (!mounted) return;

    if (success) {
      SacSnackBar.showMessenger(
        messenger,
        'activities.detail.deleted_ok'.tr(),
        isSuccess: true,
      );
      navigator.pop();
    } else {
      final deleteState = ref.read(deleteActivityNotifierProvider);
      final errorMsg = deleteState.hasError
          ? deleteState.error?.toString() ??
              'activities.detail.error_delete'.tr()
          : 'activities.detail.error_delete'.tr();
      SacSnackBar.showMessenger(messenger, errorMsg, isError: true);
    }
  }

  Future<void> _openMeetLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Staff attendance panel (QR and manual marking) for every platform.
  void _openAttendance() {
    final activity = ref.read(activityDetailProvider(widget.activityId)).value;
    Navigator.of(context).push(
      SacSharedAxisRoute(
        builder: (_) => ActivityAttendanceView(
          activityId: widget.activityId,
          activityName: activity?.name ?? '',
          isVirtual: activity?.platform == 1,
        ),
      ),
    );
  }

  void _openMyQr() {
    final activity = ref.read(activityDetailProvider(widget.activityId)).value;
    Navigator.of(context).push(
      SacSharedAxisRoute(
        builder: (_) => ActivityMyQrView(
          activityId: widget.activityId,
          activityName: activity?.name ?? '',
          sectionName: activity?.clubTypeName,
        ),
      ),
    );
  }

  /// Virtual activities: staff marks who actually attended.
  Future<void> _openRoster() async {
    final activity = ref.read(activityDetailProvider(widget.activityId)).value;
    final saved = await Navigator.of(context).push<bool>(
      SacSharedAxisRoute(
        builder: (_) => ActivityManualAttendanceView(
          activityId: widget.activityId,
          activityName: activity?.name ?? '',
          showRsvp: true,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(activityDetailProvider(widget.activityId));
    ref.invalidate(attendanceRosterProvider(widget.activityId));
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date.toLocal()).inDays;
    if (diff <= 0) return 'activities.detail.relative_today'.tr();
    if (diff == 1) return 'activities.detail.relative_yesterday'.tr();
    if (diff < 7) {
      return 'activities.detail.relative_days'
          .tr(namedArgs: {'count': diff.toString()});
    }
    if (diff < 30) {
      return 'activities.detail.relative_weeks'
          .tr(namedArgs: {'count': (diff / 7).floor().toString()});
    }
    return DateFormat.yMMMd(context.locale.toString()).format(date.toLocal());
  }

  /// "meet.google.com/abc-defg" from a full link (scheme and query dropped).
  String _linkDisplay(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    final path = uri.path == '/' ? '' : uri.path;
    return '${uri.host}$path';
  }

  // ── sections ────────────────────────────────────────────────────────────────

  Widget _buildHeader(Activity activity, String locale) {
    final date = activity.activityDate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          if (date != null) ...[
            ActivityDateTile(date: date, locale: locale),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    SacBadge(
                      label: activityTypeLabel(
                        activity.activityType,
                        activity.activityTypeName,
                      ),
                      variant: activityTypeBadgeVariant(activity.activityType),
                    ),
                    if (activity.activitySeriesId != null)
                      SacBadge.success(
                        label: 'activities.series.badge'.tr(),
                        icon: HugeIcons.strokeRoundedRefresh,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(Activity activity, String locale) {
    final date = activity.activityDate;
    final time = activityTimeLabel(activity.activityTime);
    final end = activity.lastDay;
    final isMultiDay = date != null &&
        end != null &&
        DateTime(date.year, date.month, date.day) != end;
    final dateDetail = [
      if (time != null) time,
      if (isMultiDay)
        'activities.detail.until_date'
            .tr(namedArgs: {'date': activityDayMonth(end, locale)}),
    ].join(' · ');

    final sectionName = (activity.clubTypeName?.trim().isNotEmpty ?? false)
        ? activity.clubTypeName!.trim()
        : 'activities.widgets.section_fallback'
            .tr(namedArgs: {'section': '${activity.clubSectionId}'});
    final isClasses =
        activity.audience == 'classes' && activity.audienceClasses.isNotEmpty;

    final link = activity.linkMeet?.trim();
    final hasLink = link != null && link.isNotEmpty;
    final showModality = activity.platform == 1 || hasLink;
    final isMeet = hasLink && Uri.tryParse(link)?.host == 'meet.google.com';

    return SacGroupedSection(
      label: 'activities.detail.section_details'.tr(),
      action: const SizedBox.shrink(),
      children: [
        if (date != null)
          ActivityDetailRow(
            icon: HugeIcons.strokeRoundedCalendar01,
            title: activityFullDate(date, locale),
            detail: dateDetail,
          ),
        ActivityDetailRow(
          icon: HugeIcons.strokeRoundedUserGroup,
          title: isClasses
              ? 'activities.form.audience_classes'.tr()
              : activityAudienceText(activity),
          detail: sectionName,
          extra: isClasses ? ActivityAudienceClasses(activity: activity) : null,
        ),
        if (showModality)
          ActivityDetailRow(
            icon: HugeIcons.strokeRoundedComputerVideoCall,
            title: hasLink
                ? (isMeet
                    ? 'activities.detail.modality_meet'.tr()
                    : 'activities.detail.modality_link'.tr())
                : 'activities.detail.platform_virtual'.tr(),
            detail: hasLink ? _linkDisplay(link) : null,
            onTap: hasLink ? () => _openMeetLink(link) : null,
          ),
      ],
    );
  }

  Widget _buildAttendance(Activity activity, {required bool canManage}) {
    final attendees = activity.attendees ?? const <String>[];
    final isVirtual = activity.platform == 1;
    return SacGroupedSection(
      label: 'activities.detail.section_attendance'.tr(),
      count: attendees.length,
      children: [
        ActivityAttendeesSection(
          attendees: attendees,
          profiles: activity.attendeeProfiles,
          emptyMessage:
              isVirtual ? 'activities.widgets.rsvp_none_confirmed'.tr() : null,
        ),
        if (isVirtual && canManage)
          ActivityDetailRow(
            icon: HugeIcons.strokeRoundedUserCheck01,
            title: 'activities.widgets.rsvp_confirm_title'.tr(),
            detail: 'activities.widgets.rsvp_confirm_body'.tr(),
            onTap: _openRoster,
          ),
      ],
    );
  }

  Widget _buildOrganizer(Activity activity) {
    final created = activity.createdAt;
    final name =
        activity.creatorName ?? 'activities.detail.creator_system'.tr();
    return SacGroupedSection(
      label: 'activities.detail.section_organizer'.tr(),
      action: const SizedBox.shrink(),
      children: [
        ActivityDetailRow(
          leading: SacMemberAvatar(
            imageUrl: activity.creatorImage,
            name: name,
            size: 32,
          ),
          title: name,
          detail: created == null
              ? null
              : 'activities.detail.created_ago'
                  .tr(namedArgs: {'when': _relativeDate(created)}),
        ),
      ],
    );
  }

  Widget? _buildFooter(Activity activity, ActivityPhase phase,
      {required bool canManage}) {
    final action = activityFooterAction(
      activity,
      phase,
      canManageAttendance: canManage,
    );
    switch (action) {
      case ActivityFooterAction.none:
        return null;
      case ActivityFooterAction.showMyQr:
        return SacButton.primary(
          key: const ValueKey('activity-footer-qr'),
          text: 'activities.widgets.show_my_qr_title'.tr(),
          icon: HugeIcons.strokeRoundedQrCode,
          onPressed: _openMyQr,
        );
      case ActivityFooterAction.manageAttendance:
        return SacButton.primary(
          key: const ValueKey('activity-footer-attendance'),
          text: 'activities.detail.footer_attendance'.tr(),
          icon: HugeIcons.strokeRoundedQrCode01,
          onPressed: _openAttendance,
        );
      case ActivityFooterAction.joinMeeting:
        return SacButton.primary(
          key: const ValueKey('activity-footer-join'),
          text: 'activities.detail.join_meeting'.tr(),
          icon: HugeIcons.strokeRoundedComputerVideoCall,
          onPressed: () => _openMeetLink(activity.linkMeet!),
        );
    }
  }

  Widget? _buildMoreAction(
    Activity activity, {
    required bool canEdit,
    required bool canDelete,
    required bool isDeleting,
  }) {
    if (!canEdit && !canDelete) return null;
    final c = context.sac;
    return SacPressable(
      listenOnly: true,
      child: IconButton(
        key: const ValueKey('activity-more-action'),
        enableFeedback: false,
        tooltip: 'nav.more_options'.tr(),
        constraints: const BoxConstraints(
          minWidth: SacTopBar.touchTarget,
          minHeight: SacTopBar.touchTarget,
        ),
        onPressed: isDeleting
            ? null
            : () => _openMoreSheet(
                  activity,
                  canEdit: canEdit,
                  canDelete: canDelete,
                ),
        icon: SacStateSwap(
          child: isDeleting
              ? SacLoadingSmall(
                  key: const ValueKey('activity-delete-loading'),
                  color: c.text,
                )
              : HugeIcon(
                  key: const ValueKey('activity-more-idle'),
                  icon: HugeIcons.strokeRoundedMoreHorizontal,
                  size: 22,
                  color: c.text,
                ),
        ),
      ),
    );
  }

  Widget _buildBody(
    Activity activity, {
    required bool canManage,
    required Widget? footer,
  }) {
    final locale = context.locale.toString();
    final description = activity.description?.trim() ?? '';

    final list = RefreshIndicator(
      color: SacAccent.of(context).color,
      onRefresh: () async {
        ref.invalidate(activityDetailProvider(widget.activityId));
        await ref.read(activityDetailProvider(widget.activityId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: footer == null ? 40 : SacFrostedFooter.height + 16,
        ),
        children: [
          _buildHeader(activity, locale),
          if (activityHasMapCard(activity))
            ActivityMapCard(activity: activity, mapBuilder: widget.mapBuilder),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: ActivityStatePanel(activity: activity),
          ),
          _buildDetails(activity, locale),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ActivityDescriptionBlock(description: description),
            ),
          if (activity.platform == 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ActivityVirtualAttendance(
                activityId: activity.id,
                eyebrow: 'activities.widgets.rsvp_title'.tr(),
              ),
            ),
          _buildAttendance(activity, canManage: canManage),
          _buildOrganizer(activity),
        ],
      ),
    );

    if (footer == null) return list;
    return Stack(
      children: [
        Positioned.fill(child: list),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SacFrostedFooter(child: footer),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(activityDetailProvider(widget.activityId));
    final deleteState = ref.watch(deleteActivityNotifierProvider);
    final user = ref.watch(
      authNotifierProvider.select((v) => v.value),
    );

    final canManage = hasAnyPermission(user, const {'attendance:manage'}) ||
        hasCapability(user, 'club.operational_staff');
    final canEdit = canUpdateActivities(user);
    final canDelete = canDeleteActivities(user);
    final activity = activityAsync.value;
    final moreAction = activity == null
        ? null
        : _buildMoreAction(
            activity,
            canEdit: canEdit,
            canDelete: canDelete,
            isDeleting: deleteState.isLoading,
          );

    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: 'activities.detail.title'.tr(),
        actions: [if (moreAction != null) moreAction],
      ),
      body: activityAsync.when(
        loading: () => const ActivityDetailSkeleton(),
        error: (error, _) => SacErrorState(
          title: 'activities.detail.error_load'.tr(),
          message: userErrorMessage(error),
          onRetry: () =>
              ref.invalidate(activityDetailProvider(widget.activityId)),
        ),
        data: (data) => _buildBody(
          data,
          canManage: canManage,
          footer: _buildFooter(
            data,
            data.phaseAt(DateTime.now()),
            canManage: canManage,
          ),
        ),
      ),
    );
  }
}
