import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_list_row.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/service_credential.dart';
import '../utils/service_credential_labels.dart';
import '../utils/service_credential_status_style.dart';
import 'credential_history_row.dart';
import 'service_credential_text_row.dart';

/// «Mis constancias» with credentials: the current one as a state panel, its
/// reason and document, the action that fits its state and the older ones.
class MyCredentialsBody extends StatelessWidget {
  const MyCredentialsBody({
    super.key,
    required this.items,
    required this.withdrawing,
    required this.onUpload,
    required this.onWithdraw,
  });

  /// Already sorted, newest first. Never empty.
  final List<ServiceCredential> items;
  final Set<String> withdrawing;
  final VoidCallback onUpload;
  final void Function(ServiceCredential item) onWithdraw;

  @override
  Widget build(BuildContext context) {
    final current = items.first;
    final history = items.skip(1).toList();
    final reason = current.decisionReason?.trim();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: _StatePanel(credential: current),
        ),
        if (current.isRejected && reason != null && reason.isNotEmpty)
          SacGroupedSection(
            key: const ValueKey('credential-reason'),
            label: 'service_credentials.mine.reason_label'.tr(),
            action: const SizedBox.shrink(),
            dividerIndent: 0,
            children: [ServiceCredentialTextRow(text: reason)],
          ),
        SacGroupedSection(
          key: const ValueKey('credential-document'),
          label: 'service_credentials.mine.document_label'.tr(),
          action: const SizedBox.shrink(),
          children: [_DocumentRow(credential: current)],
        ),
        if (current.isPending)
          SacGroupedSection(
            key: const ValueKey('credential-actions'),
            label: 'service_credentials.mine.actions_label'.tr(),
            action: const SizedBox.shrink(),
            children: [
              _WithdrawRow(
                isWithdrawing: withdrawing.contains(current.id),
                onTap: () => onWithdraw(current),
              ),
            ],
          ),
        if (current.isApproved)
          SacGroupedSection(
            key: const ValueKey('credential-actions'),
            label: 'service_credentials.mine.actions_label'.tr(),
            action: const SizedBox.shrink(),
            children: [
              SacListRow(
                key: const ValueKey('credential-upload-another'),
                leading: const SacListRowIcon(
                  HugeIcons.strokeRoundedUpload01,
                ),
                title: 'service_credentials.mine.upload_another'.tr(),
                onTap: onUpload,
              ),
            ],
          ),
        if (history.isNotEmpty)
          SacGroupedSection(
            key: const ValueKey('credential-history'),
            label: 'service_credentials.mine.history_label'.tr(),
            dividerIndent: 58,
            children: [
              for (final item in history)
                CredentialHistoryRow(
                  key: ValueKey('service-credential-${item.id}'),
                  credential: item,
                ),
            ],
          ),
      ],
    );
  }
}

/// The state of the current credential, once. Read-only: there is no list of
/// states to open here.
class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.credential});

  final ServiceCredential credential;

  @override
  Widget build(BuildContext context) {
    final course = serviceCredentialTitle();
    final completed = credential.completedAt;
    final expires = credential.expiresAt;
    final reviewed = credential.reviewedAt;
    final sent = credential.createdAt;
    final String title;
    final String? message;
    if (credential.isApproved) {
      title = 'service_credentials.mine.approved_title'.tr();
      message = completed == null
          ? null
          : expires == null
              ? 'service_credentials.mine.approved_message'.tr(namedArgs: {
                  'course': course,
                  'date': serviceCredentialDate(context, completed),
                })
              : 'service_credentials.mine.approved_message_expires'
                  .tr(namedArgs: {
                  'course': course,
                  'date': serviceCredentialDate(context, completed),
                  'expires': serviceCredentialDate(context, expires),
                });
    } else if (credential.isRejected) {
      title = 'service_credentials.mine.rejected_title'.tr();
      message = reviewed == null
          ? 'service_credentials.mine.rejected_message_undated'.tr()
          : 'service_credentials.mine.rejected_message'.tr(namedArgs: {
              'date': serviceCredentialDate(context, reviewed),
            });
    } else {
      title = 'service_credentials.status.pending'.tr();
      message = sent == null
          ? 'service_credentials.mine.pending_message_undated'.tr()
          : 'service_credentials.mine.pending_message'.tr(namedArgs: {
              'date': serviceCredentialDate(context, sent),
            });
    }
    return SacStatePanel(
      key: const ValueKey('credential-state-panel'),
      style: serviceCredentialStatusStyle(
        context,
        credential.status,
        label: title,
      ),
      title: title,
      message: message,
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.credential});

  final ServiceCredential credential;

  @override
  Widget build(BuildContext context) {
    final name = credential.fileName?.trim().toLowerCase() ?? '';
    final HugeIconData icon = name.endsWith('.pdf')
        ? HugeIcons.strokeRoundedPdf01
        : name.isEmpty
            ? HugeIcons.strokeRoundedFile01
            : HugeIcons.strokeRoundedImage01;
    final completed = credential.completedAt;
    return SacListRow(
      key: const ValueKey('credential-document-row'),
      leading: SacListRowIcon(icon),
      title: serviceCredentialFileLabel(credential.fileName) ??
          'service_credentials.mine.document_fallback'.tr(),
      subtitle: completed == null
          ? null
          : 'service_credentials.row.completed_on'.tr(namedArgs: {
              'date': serviceCredentialDate(context, completed),
            }),
    );
  }
}

class _WithdrawRow extends StatelessWidget {
  const _WithdrawRow({required this.isWithdrawing, required this.onTap});

  final bool isWithdrawing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SacListRow(
      key: const ValueKey('credential-withdraw'),
      leading: const SacListRowIcon(
        HugeIcons.strokeRoundedDelete02,
        destructive: true,
      ),
      title: 'service_credentials.mine.withdraw'.tr(),
      titleColor: context.sac.onErrorContainer,
      showChevron: false,
      enabled: !isWithdrawing,
      trailing: isWithdrawing ? const SacLoadingSmall() : null,
      onTap: onTap,
    );
  }
}
