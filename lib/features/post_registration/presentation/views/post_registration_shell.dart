import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/utils/run_delete_account_flow.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../domain/entities/completion_status.dart';
import '../providers/post_registration_flow_providers.dart';
import '../providers/post_registration_providers.dart';
import '../providers/personal_info_providers.dart';
import '../widgets/bottom_navigation_buttons.dart';
import '../widgets/step_indicator.dart';
import 'club_selection_step_view.dart';
import 'personal_info_step_view.dart';
import 'photo_step_view.dart';
import '../providers/club_selection_providers.dart';

/// El avance llegó vacío (sin error): se trata igual que un fallo.
class _NoCompletionStatus implements Exception {
  const _NoCompletionStatus();
}

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
  bool _confirmingFinish = false;
  bool _statusLoaded = false;

  /// Por qué no se pudo leer el avance (null = cargando o ya cargado).
  Object? _loadError;
  int _currentStep = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompletionStatus();
    });
  }

  Future<void> _loadCompletionStatus() async {
    final userId = ref.read(authNotifierProvider).valueOrNull?.id;
    final CompletionStatus? status;
    try {
      status = await ref.read(completionStatusProvider.future);
    } catch (error) {
      // Nunca un spinner infinito: error con reintentar y cerrar sesión.
      if (mounted) setState(() => _loadError = error);
      return;
    }
    if (!mounted) return;
    if (status == null) {
      setState(() => _loadError = const _NoCompletionStatus());
      return;
    }

    // Sin fecha de nacimiento el servidor aún no libera la cuenta, aunque el
    // post-registro figure completo: salir al inicio rebotaría aquí otra vez.
    // Se queda en el paso 2, que es donde se guarda la fecha.
    final awaitingBirthday = ref.read(authNotifierProvider).valueOrNull?.mode ==
        AccountMode.profileIncomplete;

    if (status.isComplete && !awaitingBirthday) {
      ref
          .read(authNotifierProvider.notifier)
          .markPostRegisterComplete(forUserId: userId);
      context.go(RouteNames.homeDashboard);
      return;
    }

    final step = status.isComplete ? 2 : status.currentStep;
    _currentStep = step;
    ref.read(currentStepProvider.notifier).state = step;

    // Create PageController at the correct initial page BEFORE building
    _pageController = PageController(initialPage: step - 1);
    setState(() => _statusLoaded = true);
  }

  void _retryLoad() {
    setState(() => _loadError = null);
    ref.invalidate(completionStatusProvider);
    _loadCompletionStatus();
  }

  Future<void> _signOutFromError() async {
    final success = await ref.read(authNotifierProvider.notifier).signOut();
    if (!success && mounted) {
      SacSnackBar.show(
          context, tr('post_registration.shell.error_logout_failed'));
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    ref.read(currentStepProvider.notifier).state = step;
    if (SacMotion.reduceMotionOf(context)) {
      _pageController?.jumpToPage(step - 1);
    } else {
      _pageController?.animateToPage(
        step - 1,
        duration: SacMotion.modal,
        curve: SacMotion.easeOut,
      );
    }
  }

  void _onBack() {
    final currentStep = _currentStep;
    if (currentStep > 1) {
      _goToStep(currentStep - 1);
    }
  }

  Future<void> _onContinue() async {
    if (_isCompletingStep) return;
    final currentStep = _currentStep;

    if (currentStep == 1) {
      await _completeStep1();
    } else if (currentStep == 2) {
      await _completeStep2();
    } else {
      await _completeStep3();
    }
  }

  Future<void> _completeStep1() async {
    setState(() => _isCompletingStep = true);
    try {
      final result = await ref
          .read(postRegistrationFlowNotifierProvider.notifier)
          .completeStep1();

      if (!mounted) return;
      if (result.success) {
        _goToStep(2);
      } else {
        SacSnackBar.show(
            context,
            result.errorMessage ??
                tr('post_registration.shell.error_step_failed'));
      }
    } finally {
      if (mounted) setState(() => _isCompletingStep = false);
    }
  }

  Future<void> _completeStep2() async {
    final authState = ref.read(authNotifierProvider);
    final user = authState.valueOrNull;
    final userId = user?.id;
    if (userId == null) return;
    final awaitingBirthday = user?.mode == AccountMode.profileIncomplete;

    final canReadSensitiveData = canReadSensitiveStep2Data(userId, user);

    setState(() => _isCompletingStep = true);
    try {
      final result = await ref
          .read(postRegistrationFlowNotifierProvider.notifier)
          .completeStep2(canReadSensitiveData: canReadSensitiveData);

      if (!mounted) return;
      if (result.success) {
        // La fecha de nacimiento acaba de guardarse: el servidor reclasifica la
        // cuenta (menor supervisado o adulto). Se vuelve a pedir `/auth/me` para
        // que el modo y el router lo sigan sin esperar al paso 3.
        final fresh = await ref
            .read(authNotifierProvider.notifier)
            .refreshCurrentUser(keepCurrentOnFailure: true);
        if (!mounted) return;
        // Una cuenta sin fecha de nacimiento que sigue así no puede continuar:
        // el paso 3 sería rechazado con 403 hasta que el servidor la libere.
        final stillRestricted = awaitingBirthday &&
            (fresh ?? ref.read(authNotifierProvider).valueOrNull)?.mode ==
                AccountMode.profileIncomplete;
        if (stillRestricted) {
          SacSnackBar.show(
            context,
            tr('post_registration.shell.error_step_failed'),
          );
          return;
        }
        _goToStep(3);
      } else {
        SacSnackBar.show(
            context,
            result.errorMessage ??
                tr('post_registration.shell.error_step_failed'));
      }
    } finally {
      if (mounted) setState(() => _isCompletingStep = false);
    }
  }

  /// ¿Se puede finalizar sin perder la ficha firmada del menor (paso 3)?
  ///
  /// Subiendo: se espera (aviso). Elegida pero sin subir (falló o no es
  /// válida): se pide confirmar, para no dejar un callejón sin salida si el
  /// almacén no responde; la ficha se puede subir luego desde Mi familia.
  Future<bool> _consentFormAllowsFinish() async {
    switch (ref.read(consentFormPhaseProvider)) {
      case ConsentFormPhase.idle:
        return true;
      case ConsentFormPhase.uploading:
        SacSnackBar.show(
          context,
          tr('post_registration.consent_form.uploading_block'),
        );
        return false;
      case ConsentFormPhase.pendingFile:
        final confirmed = await SacDialog.show(
          context,
          title: tr('post_registration.consent_form.pending_title'),
          content: tr('post_registration.consent_form.pending_body'),
          confirmLabel: tr('post_registration.consent_form.pending_confirm'),
          cancelLabel: tr('post_registration.consent_form.pending_cancel'),
          confirmIsDestructive: true,
        );
        return confirmed == true && mounted;
    }
  }

  Future<void> _completeStep3() async {
    if (_confirmingFinish) return;
    _confirmingFinish = true;
    final bool canFinish;
    try {
      canFinish = await _consentFormAllowsFinish();
    } finally {
      _confirmingFinish = false;
    }
    if (!canFinish || !mounted) return;

    final userId = ref.read(authNotifierProvider).valueOrNull?.id;
    final result = await ref
        .read(postRegistrationFlowNotifierProvider.notifier)
        .completeStep3();

    if (!mounted) return;

    if (!result.success) {
      SacSnackBar.show(
          context,
          result.errorMessage ??
              tr('post_registration.shell.error_step_failed'));
      return;
    }

    // Update auth state so router redirects correctly
    final authNotifier = ref.read(authNotifierProvider.notifier);
    authNotifier.markPostRegisterComplete(forUserId: userId);
    await authNotifier.refreshCurrentUser(keepCurrentOnFailure: true);

    if (!mounted) return;

    context.go(RouteNames.homeDashboard);
  }

  void _onSkipPhoto() {
    _goToStep(2);
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await SacDialog.show(
      context,
      title: tr('post_registration.shell.logout_dialog_title'),
      content: tr('post_registration.shell.logout_dialog_body'),
      confirmLabel: tr('post_registration.shell.logout_dialog_confirm'),
      confirmIsDestructive: true,
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(authNotifierProvider.notifier).signOut();
      if (!success && mounted) {
        SacSnackBar.show(
            context, tr('post_registration.shell.error_logout_failed'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loadError = _loadError;
    if (!_statusLoaded && loadError != null) {
      return Scaffold(
        backgroundColor: context.sac.surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SacErrorState(
                  key: const ValueKey('post_registration_load_error'),
                  title: tr('post_registration.shell.load_error_title'),
                  message: userErrorMessage(
                    loadError,
                    fallbackKey: 'post_registration.shell.load_error_body',
                  ),
                  onRetry: _retryLoad,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.horizontalPadding(context),
                  0,
                  Responsive.horizontalPadding(context),
                  16,
                ),
                child: SacButton.outline(
                  key: const ValueKey('post_registration_load_error_logout'),
                  text: tr('post_registration.shell.logout_tooltip'),
                  icon: HugeIcons.strokeRoundedLogout01,
                  onPressed: _signOutFromError,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show loading until completion status is fetched and we know the correct step
    if (!_statusLoaded) {
      return Scaffold(
        backgroundColor: context.sac.surface,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final providerStep = ref.watch(currentStepProvider);
    final currentStep = _currentStep;
    if (providerStep != currentStep) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(currentStepProvider.notifier).state = currentStep;
      });
    }
    final authUser =
        ref.watch(authNotifierProvider.select((v) => v.valueOrNull));
    // Mientras se actúa por un menor, o para un adolescente supervisado, la
    // cuenta no es de quien tiene el teléfono en la mano.
    final canDeleteAccount = canDeleteAccountInPostRegistration(
      authUser,
      acting: ref.watch(actingDependentProvider) != null,
    );
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
              animate: true,
              initialDelay: const Duration(milliseconds: 60),
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('post_registration.shell.title'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.sac.text,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SacPressable(
                      listenOnly: true,
                      child: IconButton(
                        enableFeedback: false,
                        onPressed: _showLogoutDialog,
                        icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedLogout01),
                        color: context.sac.text,
                        tooltip: tr('post_registration.shell.logout_tooltip'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    if (canDeleteAccount) ...[
                      const SizedBox(width: 8),
                      SacPressable(
                        listenOnly: true,
                        child: IconButton(
                          key: const ValueKey(
                              'post_registration_delete_account'),
                          enableFeedback: false,
                          onPressed: () => runDeleteAccountFlow(context, ref),
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedDelete02,
                          ),
                          color: context.sac.text,
                          tooltip: tr('profile.settings.delete_account_tile'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
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
                          color: SacAccent.of(context).light,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tr('post_registration.shell.step_counter',
                              namedArgs: {
                                'current': '$currentStep',
                                'total': '3'
                              }),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SacAccent.of(context).color,
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
              animate: true,
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
                onPageChanged: (index) {
                  final step = index + 1;
                  if (_currentStep == step) return;
                  setState(() => _currentStep = step);
                  ref.read(currentStepProvider.notifier).state = step;
                },
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
