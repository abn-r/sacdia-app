import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Botones de navegación fijos en la parte inferior del post-registro
///
/// Muestra botones "Regresar" y "Continuar" según el paso actual.
class BottomNavigationButtons extends StatelessWidget {
  /// Paso actual (base 1)
  final int currentStep;

  /// Número total de pasos
  final int totalSteps;

  /// Indica si el botón "Continuar" está habilitado
  final bool canContinue;

  /// Indica si se está procesando una acción
  final bool isLoading;

  /// Callback al presionar "Regresar"
  final VoidCallback? onBack;

  /// Callback al presionar "Continuar"
  final VoidCallback? onContinue;

  const BottomNavigationButtons({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.canContinue,
    this.isLoading = false,
    this.onBack,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final showBack = currentStep > 1;
    final showContinue = currentStep <= totalSteps;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Botón "Regresar"
            if (showBack)
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : onBack,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.sacGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Regresar',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.sacGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            if (showBack && showContinue) const SizedBox(width: 16),

            // Botón "Continuar"
            if (showContinue)
              Expanded(
                child: ElevatedButton(
                  onPressed: canContinue && !isLoading ? onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sacGreen,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Continuar',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
