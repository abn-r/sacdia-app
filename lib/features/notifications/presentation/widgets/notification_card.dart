import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../domain/entities/notification_item.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import '../providers/notifications_providers.dart';
import 'notification_type_badge.dart';

/// Fila de bandeja para una notificación.
///
/// La interacción principal es toda la fila: marca como leída de forma
/// optimista y abre un detalle legible. El diseño prioriza escaneo rápido,
/// targets táctiles amplios y bajo ruido visual.
class NotificationCard extends ConsumerWidget {
  final NotificationItem notification;

  const NotificationCard({super.key, required this.notification});

  Future<void> _showDetailsSheet(
    BuildContext context, {
    required bool isReadForDialog,
  }) {
    final c = context.sac;
    final visual = notificationVisualConfig(
      source: notification.source,
      targetType: notification.targetType,
    );
    final createdAt = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(notification.createdAt.toLocal());

    return showModalBottomSheet<void>(
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
                  borderRadius: BorderRadius.circular(28),
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
                  borderRadius: BorderRadius.circular(28),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: sheetC.textTertiary.withValues(
                                alpha: 0.36,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NotificationTypeBadge(
                              type: notification.targetType,
                              source: notification.source,
                              size: 52,
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
                              child: IconButton(
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
                          ],
                        ),
                        const SizedBox(height: 18),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(
                              visual.iconColor.withValues(alpha: 0.04),
                              sheetC.surfaceVariant,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sheetC.borderLight),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              notification.body,
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: sheetC.text,
                                    height: 1.52,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DetailSection(
                          children: [
                            _DetailRow(
                              icon: HugeIcons.strokeRoundedLabel,
                              label: 'notifications.inbox.detail_type'.tr(),
                              value: visual.label,
                            ),
                            _DetailRow(
                              icon: isReadForDialog
                                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                                  : HugeIcons.strokeRoundedNotification01,
                              label: isReadForDialog
                                  ? 'notifications.inbox.detail_read'.tr()
                                  : 'notifications.inbox.detail_unread'.tr(),
                              value: createdAt,
                            ),
                            _DetailRow(
                              icon: HugeIcons.strokeRoundedClock04,
                              label: 'notifications.inbox.detail_received'.tr(),
                              value:
                                  '$createdAt · ${_relativeTime(notification.createdAt)}',
                            ),
                            if (notification.senderName != null)
                              _DetailRow(
                                icon: HugeIcons.strokeRoundedUser,
                                label:
                                    'notifications.inbox.detail_sent_by'.tr(),
                                value: notification.senderName!,
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SacButton.primary(
                          text: 'notifications.inbox.detail_accept'.tr(),
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(),
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
    await _showDetailsSheet(
      context,
      isReadForDialog: notification.isRead || deliveryId != null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final isUnread = !notification.isRead;
    final visual = notificationVisualConfig(
      source: notification.source,
      targetType: notification.targetType,
    );
    final rowColor = isUnread
        ? Color.alphaBlend(
            visual.iconColor.withValues(alpha: 0.055),
            c.surface,
          )
        : c.surface;
    final borderColor =
        isUnread ? visual.iconColor.withValues(alpha: 0.18) : c.borderLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Semantics(
        button: true,
        label: '${notification.title}. ${notification.body}',
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: rowColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: InkWell(
              onTap: () => _handleTap(context, ref),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        NotificationTypeBadge(
                          type: notification.targetType,
                          source: notification.source,
                          size: 46,
                        ),
                        if (isUnread)
                          Positioned(
                            right: -1,
                            top: -1,
                            child: _UnreadDot(color: visual.iconColor),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: c.text,
                                        fontWeight: isUnread
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        height: 1.22,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  _relativeTime(notification.createdAt),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: c.textTertiary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            notification.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: c.textSecondary,
                                  height: 1.38,
                                ),
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _MetaLabel(
                                icon: visual.icon,
                                text: visual.label,
                                color: visual.iconColor,
                              ),
                              if (isUnread)
                                _MetaLabel(
                                  icon: HugeIcons.strokeRoundedCircle,
                                  text:
                                      'notifications.inbox.detail_unread'.tr(),
                                  color: AppColors.primaryDark,
                                ),
                              if (notification.senderName != null)
                                _MetaLabel(
                                  icon: HugeIcons.strokeRoundedUser,
                                  text: notification.senderName!,
                                  color: c.textTertiary,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 36,
                      height: 48,
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowRight01,
                          size: 18,
                          color: c.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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

class _UnreadDot extends StatelessWidget {
  final Color color;

  const _UnreadDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.sac.surface,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox(width: 8, height: 8),
        ),
      ),
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
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 13, color: color),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(18),
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

class _DetailRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: HugeIcon(icon: icon, size: 18, color: c.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: c.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                        height: 1.32,
                      ),
                ),
              ],
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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.borderLight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBlock(
                  width: 46,
                  height: 46,
                  radius: 999,
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
