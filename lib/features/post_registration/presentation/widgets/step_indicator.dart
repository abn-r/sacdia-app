import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Indicador de progreso para los pasos del post-registro
class StepIndicator extends StatelessWidget {
  /// Número total de pasos
  final int totalSteps;

  /// Paso actual (base 1)
  final int currentStep;

  /// Etiquetas para cada paso
  final List<String> labels;

  const StepIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.labels = const ['Foto', 'Info', 'Club'],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (index) {
          // Índices pares son los círculos, impares son las líneas
          if (index.isOdd) {
            // Línea conectora
            final stepBefore = (index ~/ 2) + 1;
            final isCompleted = stepBefore < currentStep;
            return Expanded(
              child: Container(
                height: 3,
                color: isCompleted ? AppColors.sacGreen : Colors.grey[300],
              ),
            );
          }

          // Círculo del paso
          final stepNumber = (index ~/ 2) + 1;
          final isActive = stepNumber == currentStep;
          final isCompleted = stepNumber < currentStep;
          final label = stepNumber <= labels.length ? labels[stepNumber - 1] : '';

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.sacGreen
                      : isActive
                          ? AppColors.sacGreen
                          : Colors.grey[300],
                  border: isActive
                      ? Border.all(color: AppColors.sacGreen, width: 3)
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : Text(
                          '$stepNumber',
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive || isCompleted
                      ? AppColors.sacGreen
                      : Colors.grey[600],
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
