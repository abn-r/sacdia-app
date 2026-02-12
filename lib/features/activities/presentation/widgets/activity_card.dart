import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/activity.dart';

/// Widget de tarjeta de actividad
class ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback onTap;

  const ActivityCard({
    Key? key,
    required this.activity,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono de tipo de actividad
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getTypeColor(activity.type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getTypeIcon(activity.type),
                  size: 30,
                  color: _getTypeColor(activity.type),
                ),
              ),
              const SizedBox(width: 16),
              // Información de la actividad
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd/MM/yyyy').format(activity.date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.lightTextSecondary,
                              ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('HH:mm').format(activity.date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.lightTextSecondary,
                              ),
                        ),
                      ],
                    ),
                    if (activity.location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.lightTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              activity.location!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.lightTextSecondary,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getTypeColor(activity.type).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getTypeText(activity.type),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getTypeColor(activity.type),
                        ),
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

  /// Obtiene el color según el tipo de actividad
  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return AppColors.info;
      case 'event':
        return AppColors.primaryBlue;
      case 'campout':
        return AppColors.sacGreen;
      case 'service':
        return AppColors.secondaryTeal;
      default:
        return AppColors.lightTextSecondary;
    }
  }

  /// Obtiene el icono según el tipo de actividad
  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Icons.groups;
      case 'event':
        return Icons.event;
      case 'campout':
        return Icons.forest;
      case 'service':
        return Icons.volunteer_activism;
      default:
        return Icons.event_available;
    }
  }

  /// Obtiene el texto según el tipo de actividad
  String _getTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return 'Reunión';
      case 'event':
        return 'Evento';
      case 'campout':
        return 'Campamento';
      case 'service':
        return 'Servicio';
      default:
        return 'Actividad';
    }
  }
}
