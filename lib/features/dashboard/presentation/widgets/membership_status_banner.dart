import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../auth/domain/entities/authorization_snapshot.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../post_registration/presentation/providers/post_registration_providers.dart';

/// Banner that shows the membership status of the user's active club assignment.
///
/// - **pending**: orange/amber card with clock icon and expiry date.
/// - **rejected**: red card with rejection reason and reapply button.
/// - **expired**: grey card with reapply button.
/// - **active** or null: renders nothing.
class MembershipStatusBanner extends ConsumerWidget {
  const MembershipStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final statusGrant = membershipGrantForDisplay(user?.authorization);

    // Nothing to show if there's no grant or grant is active.
    if (statusGrant == null || statusGrant.isActive) {
      return const SizedBox.shrink();
    }

    if (statusGrant.isPending) {
      return _PendingBanner(grant: statusGrant);
    }

    if (statusGrant.isRejected) {
      return _RejectedBanner(grant: statusGrant);
    }

    if (statusGrant.isExpired) {
      return const _ExpiredBanner();
    }

    return const SizedBox.shrink();
  }
}

// ── Pending ──────────────────────────────────────────────────────────────────

class _PendingBanner extends ConsumerWidget {
  final AuthorizationGrant grant;

  const _PendingBanner({required this.grant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiresAt = grant.expiresAt;
    final cancelState = ref.watch(cancelPendingMembershipRequestProvider);
    final isCancelling = cancelState.isLoading;
    String? expiryLabel;
    if (expiresAt != null) {
      final localDate = expiresAt.toLocal();
      expiryLabel = tr(
        'dashboard.banner.pending_expires',
        namedArgs: {'date': DateFormat('d MMM yyyy', 'es').format(localDate)},
      );
    }

    return _BannerContainer(
      backgroundColor: AppColors.accentLight,
      borderColor: AppColors.accent.withValues(alpha: 0.4),
      iconBackgroundColor: AppColors.accent.withValues(alpha: 0.2),
      icon: HugeIcons.strokeRoundedClock01,
      iconColor: AppColors.accentDark,
      title: tr('dashboard.banner.pending_title'),
      titleColor: AppColors.accentDark,
      subtitle: expiryLabel,
      subtitleColor: AppColors.accentDark.withValues(alpha: 0.8),
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SacButton(
            text: tr('dashboard.banner.upload_certificates'),
            variant: SacButtonVariant.primary,
            size: SacButtonSize.small,
            backgroundColor: AppColors.accent,
            textColor: Colors.white,
            onPressed: () => context.push(RouteNames.certificateImportUpload),
          ),
          SacButton(
            text: tr('dashboard.banner.cancel_request'),
            variant: SacButtonVariant.outline,
            size: SacButtonSize.small,
            isLoading: isCancelling,
            isEnabled: !isCancelling,
            onPressed: () => _cancelPendingRequest(context, ref),
          ),
        ],
      ),
    );
  }
}

// ── Rejected ─────────────────────────────────────────────────────────────────

class _RejectedBanner extends StatelessWidget {
  final AuthorizationGrant grant;

  const _RejectedBanner({required this.grant});

  @override
  Widget build(BuildContext context) {
    final reason = grant.rejectionReason;

    return _BannerContainer(
      backgroundColor: AppColors.errorLight,
      borderColor: AppColors.error.withValues(alpha: 0.4),
      iconBackgroundColor: AppColors.error.withValues(alpha: 0.2),
      icon: HugeIcons.strokeRoundedCancel01,
      iconColor: AppColors.errorDark,
      title: tr('dashboard.banner.rejected_title'),
      titleColor: AppColors.errorDark,
      subtitle: reason != null && reason.isNotEmpty ? reason : null,
      subtitleColor: AppColors.errorDark.withValues(alpha: 0.8),
      action: SacButton(
        text: tr('dashboard.banner.reapply'),
        variant: SacButtonVariant.primary,
        size: SacButtonSize.small,
        backgroundColor: AppColors.error,
        textColor: Colors.white,
        onPressed: () => _navigateToReapply(context),
      ),
    );
  }
}

// ── Expired ──────────────────────────────────────────────────────────────────

class _ExpiredBanner extends StatelessWidget {
  const _ExpiredBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return _BannerContainer(
      backgroundColor: c.surfaceVariant,
      borderColor: c.border,
      iconBackgroundColor: c.textTertiary.withValues(alpha: 0.15),
      icon: HugeIcons.strokeRoundedClock01,
      iconColor: c.textTertiary,
      title: tr('dashboard.banner.expired_title'),
      titleColor: c.textSecondary,
      action: SacButton(
        text: tr('dashboard.banner.reapply'),
        variant: SacButtonVariant.outline,
        size: SacButtonSize.small,
        onPressed: () => _navigateToReapply(context),
      ),
    );
  }
}

// ── Shared banner container ──────────────────────────────────────────────────

class _BannerContainer extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final Color iconBackgroundColor;
  final List<List<dynamic>> icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? action;

  const _BannerContainer({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconBackgroundColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    this.subtitle,
    this.subtitleColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            subtitleColor ?? titleColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: 10),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Navigation helper ────────────────────────────────────────────────────────

void _navigateToReapply(BuildContext context) {
  context.go(RouteNames.postRegistration);
}

Future<void> _cancelPendingRequest(BuildContext context, WidgetRef ref) async {
  final confirmed = await SacDialog.show(
    context,
    title: tr('dashboard.banner.cancel_request_title'),
    content: tr('dashboard.banner.cancel_request_body'),
    confirmLabel: tr('dashboard.banner.cancel_request_confirm'),
    confirmIsDestructive: true,
  );

  if (confirmed != true || !context.mounted) return;

  final userId = ref.read(authNotifierProvider).valueOrNull?.id;
  if (userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('errors.user_not_authenticated'))),
    );
    return;
  }

  final error = await ref
      .read(cancelPendingMembershipRequestProvider.notifier)
      .cancel(userId: userId);

  if (!context.mounted) return;

  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(tr('dashboard.banner.cancel_request_success'))),
  );
  context.go(RouteNames.postRegistration);
}
