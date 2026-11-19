import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/animations/sac_rolling_number.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_segment_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_summary_box.dart';

import '../../../qr/presentation/views/qr_scanner_view.dart';
import '../../domain/entities/activity_rsvp.dart';
import '../providers/activities_providers.dart';
import '../widgets/activity_detail_row.dart';
import 'activity_manual_attendance_view.dart';

/// Attendance panel for staff: how many are registered, who, and the two ways
/// to register more (scan a QR, mark by hand). Virtual activities have no QR.
class ActivityAttendanceView extends ConsumerStatefulWidget {
  const ActivityAttendanceView({
    super.key,
    required this.activityId,
    required this.activityName,
    required this.isVirtual,
  });

  final int activityId;
  final String activityName;
  final bool isVirtual;

  @override
  ConsumerState<ActivityAttendanceView> createState() =>
      _ActivityAttendanceViewState();
}

class _ActivityAttendanceViewState
    extends ConsumerState<ActivityAttendanceView> {
  void _refresh() {
    ref.invalidate(attendanceRosterProvider(widget.activityId));
    ref.invalidate(activityDetailProvider(widget.activityId));
  }

  Future<void> _scan() async {
    await Navigator.of(context).push<void>(
      SacSharedAxisRoute(
        builder: (_) => QrScannerView(activityId: widget.activityId),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _markByHand() async {
    await Navigator.of(context).push<bool>(
      SacSharedAxisRoute(
        builder: (_) => ActivityManualAttendanceView(
          activityId: widget.activityId,
          activityName: widget.activityName,
          showRsvp: widget.isVirtual,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  /// Latest added first: the attendee list order reversed. There is no
  /// per-attendee timestamp, so people missing from it go last.
  List<AttendanceRosterMember> _registered(
    List<AttendanceRosterMember> roster,
    List<String> attendees,
  ) {
    final confirmed = roster.where((m) => m.confirmed).toList();
    final index = {
      for (var i = 0; i < attendees.length; i++) attendees[i]: i,
    };
    confirmed.sort(
      (a, b) => (index[b.userId] ?? -1).compareTo(index[a.userId] ?? -1),
    );
    return confirmed;
  }

  Widget _footer() {
    if (widget.isVirtual) {
      return SacButton.primary(
        key: const ValueKey('attendance-manual'),
        text: 'activities.attendance.manual'.tr(),
        icon: HugeIcons.strokeRoundedUserCheck01,
        onPressed: _markByHand,
      );
    }
    // Two buttons of the same width and height, stacked so the labels never
    // get cut: the main action (scan) first, marking by hand under it.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacButton.primary(
          key: const ValueKey('attendance-scan'),
          text: 'activities.attendance.scan_qr'.tr(),
          icon: HugeIcons.strokeRoundedQrCode01,
          onPressed: _scan,
        ),
        const SizedBox(height: 10),
        SacButton(
          key: const ValueKey('attendance-manual'),
          text: 'activities.attendance.manual'.tr(),
          variant: SacButtonVariant.secondary,
          icon: HugeIcons.strokeRoundedUserCheck01,
          fullWidth: true,
          onPressed: _markByHand,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(attendanceRosterProvider(widget.activityId));
    final attendees =
        ref.watch(activityDetailProvider(widget.activityId)).value?.attendees ??
            const <String>[];
    final footerHeight = widget.isVirtual
        ? SacFrostedFooter.height
        : SacFrostedFooter.height + 56;

    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: 'activities.attendance.title'.tr(),
        subtitle: widget.activityName,
      ),
      body: rosterAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => SacErrorState(
          title: 'activities.attendance.load_error'.tr(),
          message: userErrorMessage(error),
          onRetry: _refresh,
        ),
        data: (roster) {
          final registered = _registered(roster, attendees);
          return Stack(
            children: [
              Positioned.fill(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(0, 8, 0, footerHeight + 16),
                  children: [
                    _Summary(
                      confirmed: registered.length,
                      total: roster.length,
                    ),
                    if (registered.isEmpty)
                      const _EmptyRegistered()
                    else
                      SacGroupedSection(
                        label: 'activities.attendance.registered'.tr(),
                        rollCount: true,
                        children: [
                          for (final member in registered)
                            ActivityDetailRow(
                              key: ValueKey('registered-${member.userId}'),
                              leading: SacMemberAvatar(
                                imageUrl: member.imageUrl,
                                name: member.name,
                                size: 32,
                              ),
                              title: member.name,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SacFrostedFooter(child: _footer()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.confirmed, required this.total});

  final int confirmed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final missing = (total - confirmed).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SacSummaryBox(
        color: c.surfaceVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'activities.attendance.registered'.tr(),
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SacRollingNumber(
                  value: confirmed,
                  suffix: 'activities.attendance.of_total'
                      .tr(namedArgs: {'total': '$total'}),
                  style: TextStyle(
                    fontSize: SacFontSize.displayMedium,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'activities.attendance.missing'
                      .tr(namedArgs: {'count': '$missing'}),
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              child: SizedBox(
                height: 8,
                child: SacSegmentRow(
                  parts: [
                    SacSegmentPart(confirmed, SacAccent.of(context).color),
                    SacSegmentPart(missing, c.border),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRegistered extends StatelessWidget {
  const _EmptyRegistered();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedUserCheck01,
            size: 36,
            color: c.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'activities.attendance.empty_title'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.titleMedium,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'activities.attendance.empty_body'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
