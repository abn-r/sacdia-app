import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../profile/presentation/widgets/setting_tile.dart';
import '../providers/service_credentials_providers.dart';
import '../utils/service_credentials_access.dart';

/// Pending-count badge: only when the count loaded and is above zero. Failure
/// or loading draws nothing (the badge is a hint, never an error).
class _PendingBadge extends ConsumerWidget {
  const _PendingBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(reviewPendingCountProvider).value;
    if (count == null || count <= 0) return const SizedBox.shrink();
    return Semantics(
      label: 'service_credentials.entry.pending_count'
          .plural(count, name: 'count'),
      excludeSemantics: true,
      child: SacBadge.warning(label: count > 99 ? '99+' : '$count'),
    );
  }
}

/// Profile section «Constancias»: «Mis constancias» for adults in their own
/// profile, and «Constancias por revisar» (with the pending count) for whoever
/// holds `service_credentials.review`. Draws nothing when neither applies
/// (acting for a minor, teen, device, restricted account, pastor or
/// coordinator without club and no capability).
class ServiceCredentialsProfileEntry extends ConsumerWidget {
  const ServiceCredentialsProfileEntry({
    super.key,
    required this.horizontalPadding,
  });

  final double horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canOwn = ref.watch(canManageOwnServiceCredentialsProvider);
    final canReview = ref.watch(canReviewServiceCredentialsProvider);
    if (!canOwn && !canReview) return const SizedBox.shrink();

    final c = context.sac;
    final accent = SacAccent.of(context);
    final tiles = <Widget>[
      if (canOwn)
        SettingTile(
          key: const ValueKey('service-credentials-mine-entry'),
          icon: HugeIcons.strokeRoundedCertificate01,
          title: 'service_credentials.entry.mine_title'.tr(),
          subtitle: 'service_credentials.entry.mine_subtitle'.tr(),
          iconColor: accent.color,
          onTap: () => context.push(RouteNames.serviceCredentials),
        ),
      if (canReview)
        SettingTile(
          key: const ValueKey('service-credentials-review-entry'),
          icon: HugeIcons.strokeRoundedFileVerified,
          title: 'service_credentials.entry.review_title'.tr(),
          subtitle: 'service_credentials.entry.review_subtitle'.tr(),
          iconColor: accent.color,
          trailing: const _PendingBadge(),
          onTap: () async {
            await context.push(RouteNames.serviceCredentialsReview);
            if (context.mounted) ref.invalidate(reviewPendingCountProvider);
          },
        ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'service_credentials.entry.section'.tr().toUpperCase(),
            style: TextStyle(
              fontSize: SacFontSize.labelSmall,
              fontWeight: FontWeight.w600,
              color: c.textTertiary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.borderLight),
                  tiles[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card of the coordination hub that opens the review queue, with the pending
/// total as a badge. Draws nothing without `service_credentials.review`.
class ServiceCredentialsReviewCard extends ConsumerWidget {
  const ServiceCredentialsReviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canReviewServiceCredentialsProvider)) {
      return const SizedBox.shrink();
    }
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: SacCard(
        animate: true,
        onTap: () async {
          await context.push(RouteNames.serviceCredentialsReview);
          if (context.mounted) ref.invalidate(reviewPendingCountProvider);
        },
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCertificate01,
                size: 22,
                color: c.onWarningContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'service_credentials.entry.review_title'.tr(),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'service_credentials.entry.review_subtitle'.tr(),
                    style:
                        textTheme.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const _PendingBadge(),
            const SizedBox(width: 8),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 18,
              color: c.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
