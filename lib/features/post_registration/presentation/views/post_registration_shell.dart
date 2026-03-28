import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/logout_cleanup.dart';
import '../providers/post_registration_providers.dart';
import '../widgets/bottom_navigation_buttons.dart';
import '../widgets/step_indicator.dart';
import 'club_selection_step_view.dart';
import 'personal_info_step_view.dart';
import 'photo_step_view.dart';
import '../providers/club_selection_providers.dart';
import '../providers/personal_info_providers.dart';

bool canReadSensitiveStep2Data(String targetUserId, UserEntity? user) {
  return canAccessSensitiveUserDataForUser(user, targetUserId: targetUserId) ||
      canReadSensitiveUserFamilyForUser(
        user,
        targetUserId: targetUserId,
        family: SensitiveUserFamily.emergencyContacts,
      ) ||
      canReadSensitiveUserFamilyForUser(
        user,
        targetUserId: targetUserId,
        family: SensitiveUserFamily.legalRepresentative,
      ) ||
      canReadSensitiveUserFamilyForUser(
        user,
        targetUserId: targetUserId,
        family: SensitiveUserFamily.health,
      );
}

/// Shell del post-registro - Estilo "Scout Vibrante"
///
/// Fondo blanco, stepper visual arriba, contenido scrollable,
/// botones de navegación fijos abajo.
///
/// Animaciones: header entra con stagger, PageView usa curva easeOutCubic
/// para una transición de pasos suave y táctil.
class PostRegistrationShell extends ConsumerStatefulWidget {
  const PostRegistrationShell({super.key});

  @override
  ConsumerState<PostRegistrationShell> createState() =>
      _PostRegistrationShellState();
}

class _PostRegistrationShellState extends ConsumerState<PostRegistrationShell> {
  PageController? _pageController;
  bool _isCompletingStep = false;
  bool _statusLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompletionStatus();
    });
  }

  Future<void> _loadCompletionStatus() async {
    final status = await ref.read(completionStatusProvider.future);
    if (status == null || !mounted) return;

    if (status.isComplete) {
      ref.read(authNotifierProvider.notifier).markPostRegisterComplete();
      context.go(RouteNames.homeDashboard);
      return;
    }

    final step = status.currentStep;
    ref.read(currentStepProvider.notifier).state = step;

    // Create PageController at the correct initial page BEFORE building
    _pageController = PageController(initialPage: step - 1);
    setState(() => _statusLoaded = true);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    ref.read(currentStepProvider.notifier).state = step;
    _pageController?.animateToPage(
      step - 1,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  void _onBack() {
    final currentStep = ref.read(currentStepProvider);
    if (currentStep > 1) {
      _goToStep(currentStep - 1);
    }
  }

  Future<void> _onContinue() async {
    if (_isCompletingStep) return;
    final currentStep = ref.read(currentStepProvider);

    if (currentStep == 1) {
      await _completeStep1();
    } else if (currentStep == 2) {
      await _completeStep2();
    } else {
      await _completeStep3();
    }
  }

  Future<void> _completeStep1() async {
    final authState = ref.read(authNotifierProvider);
    final userId = authState.valueOrNull?.id;
    if (userId == null) return;

    setState(() => _isCompletingStep = true);
    try {
      final repository = ref.read(postRegistrationRepositoryProvider);
      final result = await repository.completeStep1(userId);

      result.fold(
        (failure) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        },
        (_) {
          if (mounted) _goToStep(2);
        },
      );
    } finally {
      if (mounted) setState(() => _isCompletingStep = false);
    }
  }

  Future<void> _completeStep2() async {
    final authState = ref.read(authNotifierProvider);
    final user = authState.valueOrNull;
    final userId = user?.id;
    if (userId == null) return;

    final canReadSensitiveData = canReadSensitiveStep2Data(userId, user);

    setState(() => _isCompletingStep = true);
    try {
      if (canReadSensitiveData) {
        await ref.read(savePersonalInfoProvider.notifier).save();
      } else {
        final dataSource = ref.read(personalInfoDataSourceProvider);
        await dataSource.completeStep2(userId);
      }
      if (mounted) _goToStep(3);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo completar este paso. Por favor intentá de nuevo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCompletingStep = false);
    }
  }

  Future<void> _completeStep3() async {
    final authState = ref.read(authNotifierProvider);
    final userId = authState.valueOrNull?.id;
    if (userId == null) return;

    ref.read(isSavingStep3Provider.notifier).state = true;

    try {
      final dataSource = ref.read(clubSelectionDataSourceProvider);
      await dataSource.completeStep3(
        userId: userId,
        countryId: ref.read(selectedCountryProvider)!,
        unionId: ref.read(selectedUnionProvider)!,
        localFieldId: ref.read(selectedLocalFieldProvider)!,
        clubSectionId: ref.read(selectedClubSectionProvider)!,
        classId: ref.read(selectedClassProvider)!,
      );
    } on Exception catch (e) {
      final msg = e.toString();
      // 409 Conflict = already completed → treat as success (idempotency)
      if (!msg.contains('409') && mounted) {
        ref.read(isSavingStep3Provider.notifier).state = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.replaceFirst('Exception: ', ''))),
        );
        return;
      }
    } finally {
      if (mounted) {
        ref.read(isSavingStep3Provider.notifier).state = false;
      }
    }

    if (!mounted) return;

    // Update auth state so router redirects correctly
    ref.read(authNotifierProvider.notifier).markPostRegisterComplete();

    if (mounted) context.go(RouteNames.homeDashboard);
  }

  void _onSkipPhoto() {
    _goToStep(2);
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Si cierras sesión ahora, deberás completar este proceso cuando vuelvas a ingresar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(authNotifierProvider.notifier).signOut();
      if (success) clearUserStateOnLogout(ref);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cerrar la sesión. Intenta de nuevo.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading until completion status is fetched and we know the correct step
    if (!_statusLoaded) {
      return Scaffold(
        backgroundColor: context.sac.surface,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final currentStep = ref.watch(currentStepProvider);
    final authUser = ref.watch(authNotifierProvider).valueOrNull;
    final selectedPhoto = ref.watch(selectedPhotoPathProvider);
    final isUploading = ref.watch(isUploadingPhotoProvider);
    final isSavingStep3 = ref.watch(isSavingStep3Provider);
    final hPad = Responsive.horizontalPadding(context);
    final targetUserId = authUser?.id ?? '';
    final canReadStep2SensitiveData =
        canReadSensitiveStep2Data(targetUserId, authUser);
    final canManageStep2AdministrativeCompletion =
        canManageAdministrativeCompletionForUser(
      authUser,
      targetUserId: targetUserId,
    );

    bool canContinue = false;
    switch (currentStep) {
      case 1:
        canContinue = selectedPhoto != null && !isUploading;
        break;
      case 2:
        canContinue = canReadStep2SensitiveData
            ? ref.watch(canCompleteStep2Provider)
            : canManageStep2AdministrativeCompletion;
        break;
      case 3:
        final canComplete3 = ref.watch(canCompleteStep3Provider);
        canContinue = canComplete3 && !isSavingStep3;
        break;
    }

    return Scaffold(
      backgroundColor: context.sac.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header with staggered entrance on first mount
            StaggeredListItem(
              index: 0,
              initialDelay: const Duration(milliseconds: 60),
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Completar perfil',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.sac.text,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _showLogoutDialog,
                      icon: const Icon(Icons.logout_rounded),
                      color: context.sac.text,
                      tooltip: 'Cerrar sesión',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    // Step counter badge — animates value change implicitly
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Container(
                        key: ValueKey(currentStep),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$currentStep de 3',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Stepper — slides in after header
            StaggeredListItem(
              index: 1,
              initialDelay: const Duration(milliseconds: 60),
              child: StepIndicator(
                totalSteps: 3,
                currentStep: currentStep,
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController!,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const PhotoStepView(),
                  PersonalInfoStepView(
                    canReadSensitiveData: canReadStep2SensitiveData,
                    canManageAdministrativeCompletion:
                        canManageStep2AdministrativeCompletion,
                    targetUserId: targetUserId,
                  ),
                  const ClubSelectionStepView(),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom nav buttons
      bottomNavigationBar: BottomNavigationButtons(
        currentStep: currentStep,
        totalSteps: 3,
        canContinue: canContinue,
        isLoading: isUploading || isSavingStep3 || _isCompletingStep,
        onBack: _onBack,
        onContinue: _onContinue,
        onSkip: currentStep == 1 ? _onSkipPhoto : null,
      ),
    );
  }
}
