import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/sac_font_size.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';

import 'welcome_header.dart';

/// Header of a home that has no club (supervisor, coordinator, pastor): the
/// same [WelcomeHeader] the club dashboard draws (greeting by the hour, first
/// name, bell with the unread count, photo), a context line under the name and
/// the title of the screen below it.
///
/// Name and photo come from the signed-in user, the bell opens the inbox. Use
/// it ONLY when the screen is the home; pushed or tab routes of a user with a
/// club keep their `SacTopBar`.
class ClubLessHomeHeader extends ConsumerWidget {
  const ClubLessHomeHeader({
    super.key,
    required this.sectionTitle,
    this.contextLabel,
    this.contextIcon = HugeIcons.strokeRoundedGlobe02,
  });

  /// Title under the greeting («Supervisión», «Coordinación»).
  final String sectionTitle;

  /// Line under the name (territory, scope). Omitted when null or empty.
  final String? contextLabel;

  final HugeIconData contextIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final name = (user?.name?.trim().isNotEmpty ?? false)
        ? user!.name!.trim()
        : (user?.email?.split('@').first ?? '');
    final label = contextLabel?.trim();
    final hPad = Responsive.horizontalPadding(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WelcomeHeader(
          userName: name,
          userAvatar: user?.avatar,
          unreadNotificationsCount: ref.watch(unreadNotificationsCountProvider),
          onNotificationsTap: () => context.push(RouteNames.notificationsInbox),
          subtitle: label == null || label.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: buildIcon(
                          contextIcon,
                          size: 14,
                          color: SacAccent.of(context).color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: SacFontSize.bodySmall,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 4),
          child: Semantics(
            header: true,
            child: Text(
              sectionTitle,
              style: TextStyle(
                fontSize: SacFontSize.headlineMedium,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: c.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
