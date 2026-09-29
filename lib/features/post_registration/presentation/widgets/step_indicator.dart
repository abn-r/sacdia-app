import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
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
    this.labels = const [],
  });

  @override
  Widget build(BuildContext context) {
    final resolvedLabels = labels.isNotEmpty
        ? labels
        : [
            tr('post_registration.steps.photo'),
            tr('post_registration.steps.data'),
            tr('post_registration.steps.club'),
          ];
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
                duration: SacMotion.reduceMotionOf(context)
                    ? SacMotion.reducedFade
                    : SacMotion.standard,
                curve: SacMotion.easeOut,
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
          final label = stepNumber <= resolvedLabels.length
              ? resolvedLabels[stepNumber - 1]
              : '';

          final reduce = SacMotion.reduceMotionOf(context);
          final stepDuration =
              reduce ? SacMotion.reducedFade : SacMotion.standard;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: stepDuration,
                curve: SacMotion.easeOut,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.secondary
                      : isActive
                          ? SacAccent.of(context).color
                          : context.sac.surface,
                  border: Border.all(
                    color: isCompleted
                        ? AppColors.secondary
                        : isActive
                            ? SacAccent.of(context).color
                            : context.sac.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: SacStateSwap(
                    duration: SacMotion.standard,
                    child: isCompleted
                        ? const HugeIcon(
                            key: ValueKey('step-done'),
                            icon: HugeIcons.strokeRoundedTick02,
                            color: Colors.white,
                            size: 14,
                          )
                        : AnimatedDefaultTextStyle(
                            key: const ValueKey('step-num'),
                            duration: stepDuration,
                            curve: SacMotion.easeOut,
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : context.sac.textTertiary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                            child: Text('$stepNumber'),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: stepDuration,
                curve: SacMotion.easeOut,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive || isCompleted
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: isCompleted
                      ? AppColors.secondary
                      : isActive
                          ? SacAccent.of(context).color
                          : context.sac.textTertiary,
                ),
                child: Text(label),
              ),
            ],
          );
        }),
      ),
    );
  }
}
