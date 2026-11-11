import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/theme/sac_accent.dart';
import '../../../../core/config/dashboard_drill_in.dart';
import '../../../../core/notifications/enrollment_review_push_route.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../investiture_requests/presentation/utils/investiture_notification_routes.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../enrollment/presentation/providers/enrollment_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../members/presentation/utils/member_requests_notification_route.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/notification_action.dart';
import '../../domain/notification_body_parser.dart';
import '../../domain/notification_time.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import '../providers/notifications_providers.dart';
import 'notification_type_badge.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Fila de bandeja para una notificación.
///
/// La interacción principal es toda la fila: marca como leída de forma
/// optimista y abre un detalle legible. El diseño prioriza escaneo rápido,
/// targets táctiles amplios y bajo ruido visual.
class NotificationCard extends ConsumerWidget {
  final NotificationItem notification;

  /// Time shown in the row; defaults to [notificationInboxTime]. The inbox
  /// passes a shorter one because the day group already says the date.
  final String? timeLabel;

  const NotificationCard({
    super.key,
    required this.notification,
    this.timeLabel,
  });

  Future<void> _showDetailsSheet(BuildContext context) {
    final c = context.sac;
    final visual = notificationVisualConfig(
      context: context,
      source: notification.source,
      targetType: notification.targetType,
    );
    final parsedBody = parseNotificationBody(notification.body);
    final action = notificationActionFor(notification.source);

    return showSacSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: c.barrierColor,
      builder: (sheetContext) {
        final sheetC = sheetContext.sac;
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.86;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + bottomInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: sheetC.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                  border: Border.all(color: sheetC.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: sheetC.shadow.withValues(alpha: 0.20),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SacSheetGrabber(padded: false),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NotificationTypeBadge(
                              type: notification.targetType,
                              source: notification.source,
                              size: 48,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _MetaLabel(
                                    icon: visual.icon,
                                    text: visual.label,
                                    color: visual.iconColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    notification.title,
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: sheetC.text,
                                          fontWeight: FontWeight.w800,
                                          height: 1.14,
                                          letterSpacing: -0.15,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: SacPressable(
                                listenOnly: true,
                                child: IconButton(
                                  enableFeedback: false,
                                  onPressed: () => Navigator.of(
                                    sheetContext,
                                  ).pop(),
                                  tooltip:
                                      'notifications.inbox.detail_accept'.tr(),
                                  icon: HugeIcon(
                                    icon: HugeIcons.strokeRoundedCancel01,
                                    size: 20,
                                    color: sheetC.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _NotificationBodyBlock(
                          parsed: parsedBody,
                          accent: visual.toneColor,
                        ),
                        const SizedBox(height: 12),
                        // When and who, in one quiet line: the category is
                        // already in the header.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Wrap(
                            spacing: 14,
                            runSpacing: 6,
                            children: [
                              _MetaLabel(
                                icon: HugeIcons.strokeRoundedClock01,
                                text: notificationReceivedLabel(
                                  notification.createdAt,
                                ),
                                color: sheetC.textSecondary,
                                semanticsPrefix:
                                    'notifications.inbox.detail_received'.tr(),
                              ),
                              if (notification.senderName != null)
                                _MetaLabel(
                                  icon: HugeIcons.strokeRoundedUser,
                                  text: notification.senderName!,
                                  color: sheetC.textSecondary,
                                  semanticsPrefix:
                                      'notifications.inbox.detail_sent_by'.tr(),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (action != null) ...[
                          SacButton.primary(
                            key: const ValueKey('notification-detail-action'),
                            text: action.labelKey.tr(),
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              final router = GoRouter.of(context);
                              if (isDashboardDrillIn(action.route)) {
                                unawaited(
                                    openDashboardDrillIn(router, action.route));
                              } else {
                                router.go(action.route);
                              }
                            },
                            borderRadius: 16,
                          ),
                          const SizedBox(height: 4),
                          SacButton.text(
                            text: 'notifications.inbox.detail_close'.tr(),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ] else
                          SacButton.primary(
                            text: 'notifications.inbox.detail_accept'.tr(),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            borderRadius: 16,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    final deliveryId = notification.deliveryId;

    if (!notification.isRead && deliveryId != null) {
      unawaited(
        ref.read(notificationsInboxProvider.notifier).markAsRead(deliveryId),
      );
    }

    if (!context.mounted) return;

    // Resultado de investidura: lleva a la pantalla que muestra el estado
    // (directiva → sección; el resto → su lista de investiduras).
    if (isInvestitureResultSource(notification.source)) {
      // Directiva (`investiture.board`, calculada por el servidor) → sección;
      // cualquier otra persona → su lista, que siempre existe.
      var isBoard = false;
      try {
        isBoard = hasCapability(
          await ref.read(authNotifierProvider.future),
          'investiture.board',
        );
      } catch (_) {
        // Sin sesión resuelta se trata como persona: su lista siempre existe.
      }
      if (!context.mounted) return;
      final route = investitureInboxRoute(isBoard: isBoard);
      // The board screen lives in the Inicio branch: open it on top of the
      // dashboard instead of pushing it over the root inbox route.
      if (isDashboardDrillIn(route)) {
        unawaited(openDashboardDrillIn(GoRouter.of(context), route));
      } else {
        context.push(route);
      }
      return;
    }

    // Resultado de la inscripción anual: el estado y el formulario para
    // corregirla viven en el inicio.
    if (isClubEnrollmentReviewedSource(notification.source)) {
      final route = enrollmentReviewedRouteFor(
        await ref.read(authNotifierProvider.future),
        acting: ref.read(actingDependentProvider) != null,
      );
      if (!context.mounted) return;
      if (route != null) {
        ref.invalidate(currentEnrollmentProvider);
        GoRouter.of(context).go(route);
        return;
      }
    }

    // Solicitud de ingreso (incluye la de un menor con consentimiento
    // pendiente): lleva a Miembros > Solicitudes si el usuario puede verlas; si
    // no, queda el detalle informativo.
    if (isMembershipRequestSource(notification.source)) {
      // El contenedor se toma antes del `await`: el cambio de sección
      // reconstruye la sesión y este widget podría desmontarse mientras tanto.
      final container = ProviderScope.containerOf(context, listen: false);
      final route = await resolveMemberRequestsRoute(
        readUser: () => container.read(authNotifierProvider).value,
        switchContext: (assignmentId) async {
          final switched = await container
              .read(authNotifierProvider.notifier)
              .switchContext(assignmentId);
          if (switched) container.invalidate(dashboardNotifierProvider);
          return switched;
        },
        clubSectionId: clubSectionIdOfInboxTarget(
          targetType: notification.targetType,
          targetId: notification.targetId,
        ),
      );
      if (!context.mounted) return;
      if (route != null) {
        // The inbox is a root route and Members a dashboard drill-in: go to the
        // dashboard and push Members on top, so back and Inicio still work.
        unawaited(openDashboardDrillIn(GoRouter.of(context), route));
        return;
      }
    }

    await _showDetailsSheet(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final isUnread = !notification.isRead;
    final visual = notificationVisualConfig(
      context: context,
      source: notification.source,
      targetType: notification.targetType,
    );
    final theme = Theme.of(context);

    // A row of the day group in the inbox: the group card draws the surface,
    // the row only its content. Unread = bold title and a dot by the time.
    return Semantics(
      button: true,
      label: [
        visual.label,
        notification.title,
        _previewBody(notification.body),
        if (isUnread) 'notifications.inbox.detail_unread'.tr(),
      ].join('. '),
      excludeSemantics: true,
      child: SacInkWell(
        onTap: () => _handleTap(context, ref),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NotificationTypeBadge(
                type: notification.targetType,
                source: notification.source,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            visual.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: visual.iconColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeLabel ??
                              notificationInboxTime(notification.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: c.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 6),
                          _UnreadDot(color: SacAccent.of(context).color),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isUnread ? c.text : c.textSecondary,
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _previewBody(notification.body),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _previewBody(String body) {
  final parsed = parseNotificationBody(body);
  if (!parsed.hasNameList) return body;

  final section = parsed.section;
  if (section != null && section.isNotEmpty) {
    return 'notifications.inbox.recognized_in'.tr(
      namedArgs: {
        'count': '${parsed.names.length}',
        'section': section,
      },
    );
  }

  return 'notifications.inbox.recognized_count'.tr(
    namedArgs: {'count': '${parsed.names.length}'},
  );
}

class _NotificationBodyBlock extends StatelessWidget {
  final ParsedNotificationBody parsed;
  final Color accent;

  const _NotificationBodyBlock({
    required this.parsed,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    if (!parsed.hasNameList) {
      // Warm wash of the category: lighter than the icon well.
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            accent.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.07,
            ),
            c.surface,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            parsed.raw,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: c.text,
                  height: 1.52,
                ),
          ),
        ),
      );
    }

    final metaParts = <String>[
      if (parsed.section != null && parsed.section!.isNotEmpty) parsed.section!,
      if (parsed.points != null)
        'notifications.inbox.recognized_points'.tr(
          namedArgs: {'points': '${parsed.points}'},
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'notifications.inbox.recognized_count'.tr(
            namedArgs: {'count': '${parsed.names.length}'},
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: c.text,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                height: 1.2,
              ),
        ),
        if (metaParts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            metaParts.join(' · '),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
          ),
        ],
        const SizedBox(height: 14),
        _DetailSection(
          children: [
            for (final name in parsed.names) _NameRow(name: name),
          ],
        ),
      ],
    );
  }
}

class _NameRow extends StatelessWidget {
  final String name;

  const _NameRow({required this.name});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        name,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: c.text,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  final Color color;

  const _UnreadDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox(width: 8, height: 8),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  final HugeIconData icon;
  final String text;
  final Color color;

  const _MetaLabel({
    required this.icon,
    required this.text,
    required this.color,
    this.semanticsPrefix,
  });

  /// Spoken before [text] («Recibida», «Enviada por»).
  final String? semanticsPrefix;

  @override
  Widget build(BuildContext context) {
    final prefix = semanticsPrefix;
    return Semantics(
      label: prefix == null ? null : '$prefix: $text',
      excludeSemantics: prefix != null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 14, color: color),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final List<Widget> children;

  const _DetailSection({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(height: 1, thickness: 0.6, color: c.divider),
          ],
        ],
      ),
    );
  }
}

/// Skeleton/shimmer placeholder para mostrar mientras cargan las notificaciones.
class NotificationCardSkeleton extends StatefulWidget {
  const NotificationCardSkeleton({super.key});

  @override
  State<NotificationCardSkeleton> createState() =>
      _NotificationCardSkeletonState();
}

class _NotificationCardSkeletonState extends State<NotificationCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.32, end: 0.68).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final shimmerColor = Color.lerp(
          c.borderLight,
          c.textTertiary,
          _animation.value * 0.22,
        )!;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              border: Border.all(color: c.borderLight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBlock(
                  width: 40,
                  height: 40,
                  radius: AppTheme.radiusSM,
                  color: shimmerColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _SkeletonBlock(
                              height: 15,
                              radius: 8,
                              color: shimmerColor,
                            ),
                          ),
                          const SizedBox(width: 24),
                          _SkeletonBlock(
                            width: 44,
                            height: 12,
                            radius: 8,
                            color: shimmerColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _SkeletonBlock(
                        height: 12,
                        radius: 7,
                        color: shimmerColor,
                      ),
                      const SizedBox(height: 7),
                      _SkeletonBlock(
                        width: 190,
                        height: 12,
                        radius: 7,
                        color: shimmerColor,
                      ),
                      const SizedBox(height: 10),
                      _SkeletonBlock(
                        width: 82,
                        height: 12,
                        radius: 7,
                        color: shimmerColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final Color color;

  const _SkeletonBlock({
    this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
