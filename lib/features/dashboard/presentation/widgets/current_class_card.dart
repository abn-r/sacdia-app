import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget para mostrar la clase actual y su progreso
class CurrentClassCard extends StatelessWidget {
  final String? currentClassName;
  final double classProgress;

  const CurrentClassCard({
    super.key,
    this.currentClassName,
    required this.classProgress,
  });

  /// Obtiene el color según el nombre de la clase
  Color _getClassColor(String? className) {
    if (className == null) return AppColors.sacBlue;

    final lowerName = className.toLowerCase();
    if (lowerName.contains('amigo')) return AppColors.colorAmigo;
    if (lowerName.contains('compañero')) return AppColors.colorCompanero;
    if (lowerName.contains('explorador')) return AppColors.colorExplorador;
    if (lowerName.contains('orientador')) return AppColors.colorOrientador;
    if (lowerName.contains('viajero')) return AppColors.colorViajero;
    if (lowerName.contains('guía')) return AppColors.colorGuia;

    return AppColors.sacBlue;
  }

  @override
  Widget build(BuildContext context) {
    final classColor = _getClassColor(currentClassName);
    final progressPercentage = (classProgress * 100).toInt();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: classColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.school,
                    color: classColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clase Actual',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentClassName ?? 'Sin clase asignada',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.sacBlack,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progreso',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$progressPercentage%',
                      style: TextStyle(
                        fontSize: 14,
                        color: classColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: classProgress,
                    backgroundColor: Colors.grey[200],
                    color: classColor,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
            if (currentClassName != null && classProgress < 1.0) ...[
              const SizedBox(height: 12),
              Text(
                '¡Sigue adelante! Estás progresando en tu clase.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (currentClassName != null && classProgress >= 1.0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¡Felicidades! Has completado esta clase.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
