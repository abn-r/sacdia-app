import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/notification_item.dart';
import 'notification_type_badge.dart';

/// Card que muestra una notificación del historial.
///
/// Muestra: badge de tipo, título, cuerpo (máx 2 líneas) y timestamp relativo.
class NotificationCard extends StatelessWidget {
  final NotificationItem notification;

  const NotificationCard({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
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
                // Título + timestamp en la misma fila
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
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
                      Icon(
                        Icons.person_outline_rounded,
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
