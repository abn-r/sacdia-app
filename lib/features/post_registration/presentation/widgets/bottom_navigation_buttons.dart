import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

/// Botones de navegación fijos en la parte inferior del post-registro.
///
/// Estilo "Scout Vibrante": SacButton.outline para regresar,
/// SacButton.primary para continuar. Opción de omitir en paso 1.
class BottomNavigationButtons extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool canContinue;
  final bool isLoading;
  final VoidCallback? onBack;
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;

  const BottomNavigationButtons({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.canContinue,
    this.isLoading = false,
    this.onBack,
    this.onContinue,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final showBack = currentStep > 1;
    final isLastStep = currentStep == totalSteps;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: BoxDecoration(
        color: context.sac.surface,
        border: Border(
          top: BorderSide(color: context.sac.borderLight, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Back button
                if (showBack) ...[
                  Expanded(
                    flex: 2,
                    child: SacButton.outline(
                      text: 'Atrás',
                      onPressed: isLoading ? null : onBack,
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Continue button
                Expanded(
                  flex: showBack ? 3 : 1,
                  child: SacButton.primary(
                    text: isLastStep ? 'Finalizar' : 'Continuar',
                    isLoading: isLoading,
                    isEnabled: canContinue,
                    onPressed: canContinue ? onContinue : null,
                    trailingIcon: isLastStep
                        ? HugeIcons.strokeRoundedTick02
                        : HugeIcons.strokeRoundedArrowRight01,
                  ),
                ),
              ],
            ),

            // Skip option (only for step 1 - photo)
            if (onSkip != null && currentStep == 1) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: isLoading ? null : onSkip,
                child: Text(
                  'Omitir por ahora',
                  style: TextStyle(
                    color: context.sac.textTertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
