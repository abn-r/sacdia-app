import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/honor.dart';

/// Widget de tarjeta de especialidad
class HonorCard extends StatelessWidget {
  final Honor honor;
  final VoidCallback onTap;

  const HonorCard({
    Key? key,
    required this.honor,
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
              // Imagen de la especialidad
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: honor.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          honor.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.workspace_premium,
                              size: 30,
                              color: AppColors.primaryBlue,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.workspace_premium,
                        size: 30,
                        color: AppColors.primaryBlue,
                      ),
              ),
              const SizedBox(width: 16),
              // Información de la especialidad
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      honor.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (honor.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        honor.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.lightTextSecondary,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (honor.skillLevel != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Nivel ${honor.skillLevel}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.lightTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
