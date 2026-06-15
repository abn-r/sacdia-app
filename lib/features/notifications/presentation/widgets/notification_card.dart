import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/notification_item.dart';
import '../providers/notifications_providers.dart';
import 'notification_type_badge.dart';

/// Card que muestra una notificación del historial.
///
/// - Toca para marcar como leída (optimistic) si aún no fue leída.
/// - Indicador visual de no-leída: fondo tintado + punto rojo + título bold.
/// - Leída: fondo normal, sin punto, peso de título regular.
class NotificationCard extends ConsumerWidget {
  final NotificationItem notification;

  const NotificationCard({super.key, required this.notification});

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    final deliveryId = notification.deliveryId;

    if (!notification.isRead && deliveryId != null) {
      unawaited(
        ref.read(notificationsInboxProvider.notifier).markAsRead(deliveryId),
      );
    }

    if (!context.mounted) return;
    await _showDetailsDialog(
      context,
      isReadForDialog: notification.isRead || deliveryId != null,
    );
  }

  Future<void> _showDetailsDialog(
    BuildContext context, {
    required bool isReadForDialog,
  }) {
    final c = context.sac;
    final createdAt =
        DateFormat('dd/MM/yyyy HH:mm').format(notification.createdAt.toLocal());

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NotificationTypeBadge(type: notification.targetType, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  notification.title,
                  style:
                      Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.body,
                  style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                        color: c.text,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 16),
                Divider(color: c.divider),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'notifications.inbox.detail_type'.tr(),
                  value: _typeLabel(notification.targetType),
                ),
                _DetailRow(
                  label: 'notifications.inbox.detail_received'.tr(),
                  value:
                      '$createdAt · ${_relativeTime(notification.createdAt)}',
                ),
                _DetailRow(
                  label: 'notifications.inbox.detail_status'.tr(),
                  value: isReadForDialog
                      ? 'notifications.inbox.detail_read'.tr()
                      : 'notifications.inbox.detail_unread'.tr(),
                ),
                if (notification.senderName != null)
                  _DetailRow(
                    label: 'notifications.inbox.detail_sent_by'.tr(),
                    value: notification.senderName!,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('notifications.inbox.detail_accept'.tr()),
            ),
          ],
        );
      },
    );
  }

  String _typeLabel(NotificationTargetType type) {
    switch (type) {
      case NotificationTargetType.direct:
        return 'notifications.inbox.type_direct'.tr();
      case NotificationTargetType.broadcast:
        return 'notifications.inbox.type_broadcast'.tr();
      case NotificationTargetType.club:
        return 'notifications.inbox.type_club'.tr();
      case NotificationTargetType.sectionRole:
        return 'notifications.inbox.type_section_role'.tr();
      case NotificationTargetType.globalRole:
        return 'notifications.inbox.type_global_role'.tr();
      case NotificationTargetType.unknown:
        return 'notifications.inbox.type_unknown'.tr();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final isUnread = !notification.isRead;

    // Subtle background tint for unread items.
    final backgroundColor =
        isUnread ? AppColors.primary.withValues(alpha: 0.05) : c.surface;

    return InkWell(
      onTap: () => _handleTap(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            bottom: BorderSide(color: c.divider, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge de tipo
            NotificationTypeBadge(type: notification.targetType),
            const SizedBox(width: 12),

            // Contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + timestamp + punto de no-leída
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: c.text,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _relativeTime(notification.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: c.textTertiary,
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Cuerpo
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                          height: 1.4,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Remitente (si está disponible)
                  if (notification.senderName != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedUser,
                          size: 12,
                          color: c.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          notification.senderName!,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Devuelve una representación relativa del tiempo.
  ///
  /// - Menos de 1 min: "ahora"
  /// - Menos de 60 min: "hace N min"
  /// - Menos de 24 hs: "hace N hs"
  /// - Ayer: "ayer"
  /// - Misma semana: "hace N días"
  /// - Más antiguo: fecha formateada "dd/MM/yyyy"
  String _relativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} hs';

    final todayMidnight = DateTime(now.year, now.month, now.day);
    final dateMidnight = DateTime(date.year, date.month, date.day);
    final daysDiff = todayMidnight.difference(dateMidnight).inDays;

    if (daysDiff == 1) return 'ayer';
    if (daysDiff < 7) return 'hace $daysDiff días';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                  ),
            ),
          ),
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
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
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
        final shimmerColor =
            AppColors.lightBorder.withValues(alpha: _animation.value);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: c.divider, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge placeholder
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: shimmerColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                        Container(
                          width: 40,
                          height: 10,
                          decoration: BoxDecoration(
                            color: shimmerColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 12,
                      width: 200,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
