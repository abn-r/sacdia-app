import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Indicador de progreso visual para los pasos del post-registro.
///
/// 3 círculos (32px) conectados por línea horizontal animada.
/// - Completado: fondo emerald + check blanco
/// - Activo: fondo indigo + número blanco
/// - Pendiente: borde gris + número gris
/// Labels debajo: "Foto", "Datos", "Club"
class StepIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final List<String> labels;

  const StepIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.labels = const ['Foto', 'Datos', 'Club'],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepBefore = (index ~/ 2) + 1;
            final isCompleted = stepBefore < currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.secondary
                      : context.sac.borderLight,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }

          final stepNumber = (index ~/ 2) + 1;
          final isActive = stepNumber == currentStep;
          final isCompleted = stepNumber < currentStep;
          final label =
              stepNumber <= labels.length ? labels[stepNumber - 1] : '';

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.secondary
                      : isActive
                          ? AppColors.primary
                          : context.sac.surface,
                  border: Border.all(
                    color: isCompleted
                        ? AppColors.secondary
                        : isActive
                            ? AppColors.primary
                            : context.sac.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? HugeIcon(
                          icon: HugeIcons.strokeRoundedTick02,
                          color: Colors.white,
                          size: 14)
                      : Text(
                          '$stepNumber',
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : context.sac.textTertiary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              // Label
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive || isCompleted
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: isCompleted
                      ? AppColors.secondary
                      : isActive
                          ? AppColors.primary
                          : context.sac.textTertiary,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
