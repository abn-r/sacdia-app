import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/transfer_request.dart';

/// Short date of a request ("2 nov 2026"), or with the time when [withTime].
String transferDate(
  BuildContext context,
  DateTime date, {
  bool withTime = false,
}) {
  final locale = context.locale.toString();
  final local = date.toLocal();
  return withTime
      ? DateFormat('d MMM y, HH:mm', locale).format(local)
      : DateFormat('d MMM y', locale).format(local);
}

/// The one color and icon of each state, shared by the list and the detail.
SacStatusStyle transferStatusStyle(BuildContext context, TransferStatus s) {
  final label = 'transfers.status.${s.slug}'.tr();
  return switch (s) {
    TransferStatus.pending => SacStatusStyle.of(
        context,
        SacStatusKind.review,
        label: label,
        icon: HugeIcons.strokeRoundedClock01,
      ),
    TransferStatus.approved => SacStatusStyle.of(
        context,
        SacStatusKind.validated,
        label: label,
      ),
    TransferStatus.rejected => SacStatusStyle.of(
        context,
        SacStatusKind.rejected,
        label: label,
        icon: HugeIcons.strokeRoundedCancelCircle,
      ),
  };
}

/// Destination club of a request, or a neutral fallback.
String transferDestination(TransferRequest r) {
  final club = r.toClubName?.trim();
  return club == null || club.isEmpty ? 'transfers.unknown_club'.tr() : club;
}

/// Sent → in review → approved or rejected.
Future<void> showTransferStatesSheet(
  BuildContext context,
  TransferRequest request,
) {
  final pending = request.status == TransferStatus.pending;
  final reviewed = request.reviewedAt;
  final reviewedLabel =
      reviewed == null ? null : transferDate(context, reviewed);
  final last = switch (request.status) {
    TransferStatus.pending => SacStateStep(
        kind: SacStateKind.pending,
        title: 'transfers.states.decision'.tr(),
        detail: 'transfers.states.decision_detail'.tr(),
      ),
    TransferStatus.approved => SacStateStep(
        kind: SacStateKind.done,
        title: 'transfers.status.approved'.tr(),
        detail: reviewedLabel,
      ),
    TransferStatus.rejected => SacStateStep(
        kind: SacStateKind.rejected,
        title: 'transfers.status.rejected'.tr(),
        detail: [
          if (reviewedLabel != null) reviewedLabel,
          'transfers.states.rejected_detail'.tr(),
        ].join(' · '),
      ),
  };
  final created = request.createdAt;
  return showSacStatesSheet(
    context,
    title: 'transfers.states.title'.tr(),
    steps: [
      SacStateStep(
        kind: SacStateKind.done,
        title: 'transfers.states.sent'.tr(),
        detail: created == null
            ? null
            : transferDate(context, created, withTime: true),
      ),
      SacStateStep(
        kind: pending ? SacStateKind.current : SacStateKind.done,
        title: 'transfers.status.pending'.tr(),
        detail: 'transfers.states.review_detail'.tr(),
      ),
      last,
    ],
    kindLabels: SacStateKindLabels(
      done: 'transfers.states.kind_done'.tr(),
      current: 'transfers.states.kind_current'.tr(),
      rejected: 'transfers.states.kind_rejected'.tr(),
      pending: 'transfers.states.kind_pending'.tr(),
    ),
  );
}
