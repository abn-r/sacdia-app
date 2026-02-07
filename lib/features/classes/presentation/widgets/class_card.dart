import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/progressive_class.dart';
import 'progress_ring.dart';

/// Widget de tarjeta de clase progresiva
class ClassCard extends StatelessWidget {
  final ProgressiveClass progressiveClass;
  final double progress;
  final VoidCallback onTap;

  const ClassCard({
    Key? key,
    required this.progressiveClass,
    this.progress = 0.0,
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
              // Imagen de la clase
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: progressiveClass.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          progressiveClass.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.school,
                              size: 30,
                              color: AppColors.primaryBlue,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.school,
                        size: 30,
                        color: AppColors.primaryBlue,
                      ),
              ),
              const SizedBox(width: 16),
              // Información de la clase
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progressiveClass.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (progressiveClass.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        progressiveClass.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.lightTextSecondary,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Indicador de progreso
              ProgressRing(
                progress: progress,
                size: 50,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
