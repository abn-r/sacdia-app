import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/in_app_browser.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_legal_consent.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_notice.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../legal/domain/entities/legal_document.dart';
import '../../../legal/domain/entities/legal_status.dart';
import '../../../legal/presentation/providers/legal_providers.dart';
import '../providers/majority_release_providers.dart';
import '../widgets/release_account_actions.dart';

/// Flujo de un adulto liberado al cumplir la mayoría de edad (Fase 4, R6):
/// «Eres mayor de edad y aún no has reclamado tu cuenta».
///
/// 1. Agregar un correo si falta (uno sin verificar basta, R5).
/// 2. Leer y aceptar los Términos y la Privacidad vigentes.
///
/// Cuando el servidor da por completado el paso (acepta Y tiene correo) el
/// router saca a la persona de aquí: la app nunca lo deduce. Lo usa también
/// quien está congelado (aceptar descongela, R1): entonces ofrece volver a la
/// pantalla de congelado. Jamás dice que la cuenta se borrará sola.
class ReleaseView extends ConsumerStatefulWidget {
  /// Inyectable para pruebas. Por defecto abre el navegador integrado.
  final OpenLegalDocument onOpenDocument;

  const ReleaseView({super.key, this.onOpenDocument = openInAppDocument});

  @override
  ConsumerState<ReleaseView> createState() => _ReleaseViewState();
}

class _ReleaseViewState extends ConsumerState<ReleaseView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  /// Versiones (terms|privacy) con las que se marcó la casilla; si cambian, hay
  /// que marcarla otra vez.
  String? _checkedVersions;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  static String _versionsKey(LegalStatus status) =>
      '${status.versionOf(LegalDocumentTypes.terms)}|'
      '${status.versionOf(LegalDocumentTypes.privacy)}';

  bool _isChecked(LegalStatus status) =>
      _checkedVersions != null && _checkedVersions == _versionsKey(status);

  Future<void> _submitEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim().toLowerCase();
    await ref.read(releaseControllerProvider.notifier).addEmail(email);
  }

  String _acceptErrorText(String key) =>
      key.startsWith('legal_gate.') ? key.tr() : legalAcceptErrorKey.tr();

  @override
  Widget build(BuildContext context) {
    final release = ref.watch(releaseInfoProvider);
    final frozen = release?.isFrozen ?? false;
    final action = ref.watch(releaseControllerProvider);
    final c = context.sac;

    final needsEmail = release?.needsEmail ?? false;
    final needsAcceptance = release?.needsAcceptance ?? true;
    final days = release?.daysLeftAt(DateTime.now());

    final steps = <Widget>[];
    var number = 0;
    // La pista de verificación se muestra apenas se guarda el correo, aunque el
    // `/auth/me` que lo confirma (needs_email = false) llegue un instante después.
    if (action.emailAdded) {
      steps.add(SacNotice(
        key: const ValueKey('release_email_added'),
        text: 'release.email.added_hint'.tr(),
        tone: SacNoticeTone.success,
        liveRegion: true,
      ));
    }
    if (needsEmail) {
      number++;
      steps.add(_StepCard(
        key: const ValueKey('release_step_email'),
        number: number,
        title: 'release.email.title'.tr(),
        body: 'release.email.body'.tr(),
        child: _EmailStep(
          formKey: _formKey,
          controller: _emailController,
          busy: action.addingEmail,
          error: action.emailError,
          onSubmit: _submitEmail,
        ),
      ));
    }
    if (needsAcceptance) {
      number++;
      steps.add(_StepCard(
        key: const ValueKey('release_step_terms'),
        number: number,
        title: 'release.terms.title'.tr(),
        body: 'release.terms.body'.tr(),
        child: _TermsStep(
          onOpenDocument: widget.onOpenDocument,
          checkedFor: _isChecked,
          onChecked: (status, value) => setState(
            () => _checkedVersions = value ? _versionsKey(status) : null,
          ),
          action: action,
          errorText: action.acceptError == null
              ? null
              : _acceptErrorText(action.acceptError!),
        ),
      ));
    }
    if (steps.isEmpty) {
      // Completó todo: el servidor aún no lo reflejó o el router va a sacarlo.
      steps.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: SacLoading()),
      ));
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: Responsive.formPadding(context),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: Responsive.maxFormWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (frozen)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SacButton.text(
                          key: const ValueKey('release_back_to_frozen'),
                          text: 'release.back'.tr(),
                          icon: HugeIcons.strokeRoundedArrowLeft01,
                          color: c.textSecondary,
                          onPressed: () => context.go(RouteNames.releaseFrozen),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _Header(frozen: frozen),
                    const SizedBox(height: 20),
                    if (frozen)
                      SacNotice(
                        key: const ValueKey('release_frozen_notice'),
                        text: 'release.frozen_notice'.tr(),
                        tone: SacNoticeTone.info,
                      )
                    else if (days != null)
                      SacNotice(
                        key: const ValueKey('release_deadline'),
                        text: days == 0
                            ? 'release.deadline_today'.tr()
                            : 'release.deadline'
                                .tr(namedArgs: {'days': '$days'}),
                        tone: SacNoticeTone.warning,
                      ),
                    const SizedBox(height: 16),
                    for (final step in steps) ...[
                      step,
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 8),
                    ReleaseAccountActions(enabled: !action.busy),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.frozen});

  final bool frozen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = SacAccent.of(context);
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: accent.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          alignment: Alignment.center,
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedUserCheck01,
            size: 28,
            color: accent.color,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'release.title'.tr(),
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'release.body'.tr(),
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: context.sac.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    super.key,
    required this.number,
    required this.title,
    required this.body,
    required this.child,
  });

  final int number;
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'release.step'.tr(namedArgs: {'number': '$number', 'title': title}),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    required this.formKey,
    required this.controller,
    required this.busy,
    required this.error,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool busy;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacTextField(
            key: const ValueKey('release_email_field'),
            controller: controller,
            label: 'release.email.label'.tr(),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enabled: !busy,
            validator: (v) => Validators.validateEmail(v?.trim()),
            onSubmitted: (_) => onSubmit(),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            SacNotice(
              key: const ValueKey('release_email_error'),
              text: error!,
              tone: SacNoticeTone.error,
              liveRegion: true,
            ),
          ],
          const SizedBox(height: 12),
          SacButton(
            key: const ValueKey('release_email_submit'),
            text: 'release.email.submit'.tr(),
            variant: SacButtonVariant.primary,
            fullWidth: true,
            borderRadius: AppTheme.radiusFull,
            isLoading: busy,
            isEnabled: !busy,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _TermsStep extends ConsumerWidget {
  const _TermsStep({
    required this.onOpenDocument,
    required this.checkedFor,
    required this.onChecked,
    required this.action,
    required this.errorText,
  });

  final OpenLegalDocument onOpenDocument;
  final bool Function(LegalStatus status) checkedFor;
  final void Function(LegalStatus status, bool value) onChecked;
  final ReleaseActionState action;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(myLegalStatusProvider);
    final status = statusAsync.value;

    if (status == null) {
      if (statusAsync.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SacNotice(
              text: 'legal_gate.load_error'.tr(),
              tone: SacNoticeTone.error,
            ),
            const SizedBox(height: 12),
            SacButton.outline(
              text: 'legal_gate.retry'.tr(),
              borderRadius: AppTheme.radiusFull,
              onPressed: () => ref.invalidate(myLegalStatusProvider),
            ),
          ],
        );
      }
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SacLoading()),
      );
    }

    final terms = status.documentOf(LegalDocumentTypes.terms);
    final privacy = status.documentOf(LegalDocumentTypes.privacy);
    final checked = checkedFor(status);
    final canAccept = checked && !action.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacLegalConsentCheckbox(
          key: const ValueKey('release_terms_checkbox'),
          value: checked,
          enabled: !action.busy,
          termsUrl: terms?.url ?? AppConstants.termsUrl,
          privacyUrl: privacy?.url ?? AppConstants.privacyPolicyUrl,
          onOpenDocument: onOpenDocument,
          onChanged: (value) => onChecked(status, value),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          SacNotice(
            key: const ValueKey('release_accept_error'),
            text: errorText!,
            tone: SacNoticeTone.error,
            liveRegion: true,
          ),
        ],
        const SizedBox(height: 12),
        SacButton(
          key: const ValueKey('release_accept_submit'),
          text: 'release.terms.accept'.tr(),
          variant: SacButtonVariant.primary,
          fullWidth: true,
          borderRadius: AppTheme.radiusFull,
          isLoading: action.accepting,
          isEnabled: canAccept,
          onPressed: canAccept
              ? () =>
                  ref.read(releaseControllerProvider.notifier).accept(status)
              : null,
        ),
      ],
    );
  }
}
