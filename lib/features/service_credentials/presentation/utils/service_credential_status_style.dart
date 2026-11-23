import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/service_credential.dart';

/// Translated name of a review status (also the unknown one: fails closed to
/// «En revisión»).
String serviceCredentialStatusLabel(ServiceCredentialStatus status) =>
    switch (status) {
      ServiceCredentialStatus.approved =>
        'service_credentials.status.approved'.tr(),
      ServiceCredentialStatus.rejected =>
        'service_credentials.status.rejected'.tr(),
      ServiceCredentialStatus.pendingReview ||
      ServiceCredentialStatus.unknown =>
        'service_credentials.status.pending'.tr(),
    };

/// Colors and icon of a review status. [label] replaces the short status name
/// (the panel names the state in full, «Constancia aprobada»).
SacStatusStyle serviceCredentialStatusStyle(
  BuildContext context,
  ServiceCredentialStatus status, {
  String? label,
}) {
  final text = label ?? serviceCredentialStatusLabel(status);
  return switch (status) {
    ServiceCredentialStatus.approved =>
      SacStatusStyle.of(context, SacStatusKind.validated, label: text),
    ServiceCredentialStatus.rejected =>
      SacStatusStyle.of(context, SacStatusKind.rejected, label: text),
    ServiceCredentialStatus.pendingReview ||
    ServiceCredentialStatus.unknown =>
      SacStatusStyle.of(
        context,
        SacStatusKind.review,
        label: text,
        icon: HugeIcons.strokeRoundedClock01,
      ),
  };
}
