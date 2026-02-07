import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/post_registration_providers.dart';
import '../widgets/bottom_navigation_buttons.dart';
import '../widgets/step_indicator.dart';
import 'club_selection_step_view.dart';
import 'personal_info_step_view.dart';
import 'photo_step_view.dart';
import '../providers/club_selection_providers.dart';
import '../providers/personal_info_providers.dart';

/// Shell del post-registro que contiene los 3 pasos
///
/// Incluye indicadores de progreso en la parte superior y
/// botones de navegación fijos en la parte inferior.
class PostRegistrationShell extends ConsumerStatefulWidget {
  const PostRegistrationShell({super.key});

  @override
  ConsumerState<PostRegistrationShell> createState() =>
      _PostRegistrationShellState();
}

class _PostRegistrationShellState extends ConsumerState<PostRegistrationShell> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Cargar estado de completitud al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompletionStatus();
    });
  }

  Future<void> _loadCompletionStatus() async {
    final status = await ref.read(completionStatusProvider.future);
    if (status != null && mounted) {
      // Navegar al paso pendiente
      final step = status.currentStep;
      ref.read(currentStepProvider.notifier).state = step;
      if (step > 1) {
        _pageController.jumpToPage(step - 1);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    ref.read(currentStepProvider.notifier).state = step;
    _pageController.animateToPage(
      step - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onBack() {
    final currentStep = ref.read(currentStepProvider);
    if (currentStep > 1) {
      _goToStep(currentStep - 1);
    }
  }

  void _onContinue() {
    final currentStep = ref.read(currentStepProvider);
    if (currentStep < 3) {
      _goToStep(currentStep + 1);
    } else {
      // Paso 3 completado -> ir al dashboard
      context.go(RouteNames.homeDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(currentStepProvider);
    final selectedPhoto = ref.watch(selectedPhotoPathProvider);
    final isUploading = ref.watch(isUploadingPhotoProvider);

    // Determinar si se puede continuar según el paso actual
    bool canContinue = false;
    switch (currentStep) {
      case 1:
        canContinue = selectedPhoto != null && !isUploading;
        break;
      case 2:
        canContinue = ref.watch(canCompleteStep2Provider);
        break;
      case 3:
        final canComplete3 = ref.watch(canCompleteStep3Provider);
        final isSaving3 = ref.watch(isSavingStep3Provider);
        canContinue = canComplete3 && !isSaving3;
        break;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.sacRed,
        foregroundColor: Colors.white,
        title: const Text(
          'COMPLETAR REGISTRO',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Indicadores de progreso
          StepIndicator(
            totalSteps: 3,
            currentStep: currentStep,
          ),

          const Divider(height: 1),

          // Contenido de los pasos
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Paso 1: Foto de perfil
                const PhotoStepView(),

                // Paso 2: Información personal
                const PersonalInfoStepView(),

                // Paso 3: Selección de club
                const ClubSelectionStepView(),
              ],
            ),
          ),
        ],
      ),

      // Botones de navegación fijos
      bottomNavigationBar: BottomNavigationButtons(
        currentStep: currentStep,
        totalSteps: 3,
        canContinue: canContinue,
        isLoading: isUploading,
        onBack: _onBack,
        onContinue: _onContinue,
      ),
    );
  }
}
