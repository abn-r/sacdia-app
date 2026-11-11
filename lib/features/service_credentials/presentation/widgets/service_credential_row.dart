import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_notice.dart';
import '../../domain/entities/service_credential.dart';
import '../utils/service_credential_labels.dart';
import 'service_credential_status_pill.dart';

/// Icon tile (40) + gap (12): where the detail lines start.
const double _kTextInset = 52;

/// Horizontal padding inside a small [SacButton.text], so its label lines up
/// with the text column.
const double _kTextButtonPad = 16;

/// One own credential inside its status group: icon tile, title, completion date and file kind, status pill, and per-state detail
/// (rejection reason, expiry) with the action that fits (withdraw / resubmit).
class ServiceCredentialRow extends StatelessWidget {
  const ServiceCredentialRow({
    super.key,
    required this.credential,
    this.onWithdraw,
    this.onResubmit,
    this.isWithdrawing = false,
  });

  final ServiceCredential credential;

  /// Offered while the credential is not approved.
  final VoidCallback? onWithdraw;

  /// Offered on a rejected credential: upload a new one.
  final VoidCallback? onResubmit;
  final bool isWithdrawing;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final completed = credential.completedAt;
    final fileLabel = serviceCredentialFileLabel(credential.fileName);
    final detail = <String>[
      if (completed != null)
        tr('service_credentials.row.completed_on', namedArgs: {
          'date': serviceCredentialDate(context, completed),
        }),
      if (fileLabel != null) fileLabel,
    ].join(' · ');
    final reason = credential.decisionReason;
    final expires = credential.expiresAt;
    final canResubmit = credential.isRejected && onResubmit != null;
    final canWithdraw = credential.canWithdraw && onWithdraw != null;
    final hasActions = canResubmit || canWithdraw;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 12, 14, hasActions ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.light,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCertificate01,
                    size: 22,
                    color: accent.color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceCredentialTitle(),
                      style: TextStyle(
                        fontSize: SacFontSize.titleSmall,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                        height: 1.2,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textSecondary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ServiceCredentialStatusPill(status: credential.status),
            ],
          ),
          if (credential.isRejected && reason != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: _kTextInset),
              child: SacNotice(
                key: const ValueKey('rejected-reason'),
                tone: SacNoticeTone.error,
                text: tr('service_credentials.row.rejected_reason',
                    namedArgs: {'reason': reason}),
              ),
            ),
          ],
          if (credential.isApproved && expires != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: _kTextInset),
              child: Text(
                tr('service_credentials.row.valid_until', namedArgs: {
                  'date': serviceCredentialDate(context, expires),
                }),
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  color: c.textSecondary,
                ),
              ),
            ),
          ],
          if (hasActions)
            Padding(
              padding: const EdgeInsets.only(
                left: _kTextInset - _kTextButtonPad,
                top: 2,
              ),
              child: Wrap(
                children: [
                  if (canResubmit)
                    SacButton.text(
                      text: 'service_credentials.row.resubmit'.tr(),
                      onPressed: onResubmit,
                    ),
                  if (canWithdraw)
                    SacButton.text(
                      text: 'service_credentials.row.withdraw'.tr(),
                      color: c.error,
                      isLoading: isWithdrawing,
                      onPressed: onWithdraw,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
