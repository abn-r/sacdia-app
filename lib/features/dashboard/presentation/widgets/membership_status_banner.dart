import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../auth/domain/entities/authorization_snapshot.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

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
    final activeGrant = user?.authorization?.activeGrant;

    // Nothing to show if there's no grant or grant is active.
    if (activeGrant == null || activeGrant.isActive) {
      return const SizedBox.shrink();
    }

    if (activeGrant.isPending) {
      return _PendingBanner(grant: activeGrant);
    }

    if (activeGrant.isRejected) {
      return _RejectedBanner(grant: activeGrant);
    }

    if (activeGrant.isExpired) {
      return const _ExpiredBanner();
    }

    return const SizedBox.shrink();
  }
}

// ── Pending ──────────────────────────────────────────────────────────────────

class _PendingBanner extends StatelessWidget {
  final AuthorizationGrant grant;

  const _PendingBanner({required this.grant});

  @override
  Widget build(BuildContext context) {
    final expiresAt = grant.expiresAt;
    String? expiryLabel;
    if (expiresAt != null) {
      final localDate = expiresAt.toLocal();
      expiryLabel =
          'Expira el ${DateFormat('d MMM yyyy', 'es').format(localDate)}';
    }

    return _BannerContainer(
      backgroundColor: AppColors.accentLight,
      borderColor: AppColors.accent.withValues(alpha: 0.4),
      iconBackgroundColor: AppColors.accent.withValues(alpha: 0.2),
      icon: HugeIcons.strokeRoundedClock01,
      iconColor: AppColors.accentDark,
      title: 'Tu solicitud de membresia esta pendiente de aprobacion',
      titleColor: AppColors.accentDark,
      subtitle: expiryLabel,
      subtitleColor: AppColors.accentDark.withValues(alpha: 0.8),
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
      title: 'Tu solicitud de membresia fue rechazada',
      titleColor: AppColors.errorDark,
      subtitle: reason != null && reason.isNotEmpty ? reason : null,
      subtitleColor: AppColors.errorDark.withValues(alpha: 0.8),
      action: SacButton(
        text: 'Volver a solicitar',
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
      title: 'Tu solicitud de membresia expiro',
      titleColor: c.textSecondary,
      action: SacButton(
        text: 'Volver a solicitar',
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
    return Container(
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
                      color: subtitleColor ?? titleColor.withValues(alpha: 0.8),
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
    );
  }
}

// ── Navigation helper ────────────────────────────────────────────────────────

void _navigateToReapply(BuildContext context) {
  context.go(RouteNames.postRegistration);
}
