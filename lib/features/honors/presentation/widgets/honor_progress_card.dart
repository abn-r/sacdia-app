import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/user_honor.dart';

/// Widget de tarjeta de progreso de especialidad
class HonorProgressCard extends StatelessWidget {
  final UserHonor userHonor;
  final String honorName;
  final VoidCallback onTap;

  const HonorProgressCard({
    Key? key,
    required this.userHonor,
    required this.honorName,
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
              // Indicador de estado
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getStatusColor(userHonor.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getStatusIcon(userHonor.status),
                  size: 30,
                  color: _getStatusColor(userHonor.status),
                ),
              ),
              const SizedBox(width: 16),
              // Información de la especialidad
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      honorName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(userHonor.status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(userHonor.status),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(userHonor.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (userHonor.startDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Iniciado: ${_formatDate(userHonor.startDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.lightTextSecondary,
                            ),
                      ),
                    ],
                    if (userHonor.completionDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Completado: ${_formatDate(userHonor.completionDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Obtiene el color según el estado
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.info;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  /// Obtiene el icono según el estado
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.hourglass_bottom;
      case 'pending':
      default:
        return Icons.pending;
    }
  }

  /// Obtiene el texto según el estado
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completada';
      case 'in_progress':
        return 'En progreso';
      case 'pending':
      default:
        return 'Pendiente';
    }
  }

  /// Formatea una fecha
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
