import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/dependent.dart';
import '../../domain/entities/supervised_login.dart';
import '../../domain/usecases/enable_supervised_login.dart';
import '../family_error_messages.dart';
import '../providers/family_providers.dart';
import '../widgets/new_password_fields.dart';

/// ¿Puede el asistente activar el acceso propio de [summary]?
///
/// Solo si el servidor marcó que alcanzó la edad mínima y aún no lo tiene
/// (`age_milestone_reached`), no está congelado, el tutor lo es de verdad
/// (consentimiento verificado) y entra por el modo del tutor. El servidor sigue
/// siendo la autoridad (422 `SUPERVISED_LOGIN_AGE_OUT_OF_RANGE` / `NOT_ELIGIBLE`).
bool canEnableTeenLogin(DependentSummary summary) =>
    !summary.frozen &&
    summary.ageMilestoneReached &&
    summary.accessMode == AccessMode.guardianManaged &&
    summary.supervisedLogin == null &&
    summary.guardianship.isVerified;

enum _Step { method, credentials, confirm, result }

/// Asistente "Darle acceso propio" a un menor (FP3-33).
///
/// 1. Método (usuario o correo) → 2. contraseña (+ correo) con la política a la
/// vista → 3. advertencias (dejas de actuar por él, se desvinculan teléfonos) →
/// 4. resultado con el usuario generado. Si el tutor estaba actuando por ese
/// menor, al terminar sale del modo y vuelve a su lista.
class EnableTeenLoginWizard extends ConsumerStatefulWidget {
  const EnableTeenLoginWizard({super.key, required this.dependentId});

  final String dependentId;

  @override
  ConsumerState<EnableTeenLoginWizard> createState() =>
      _EnableTeenLoginWizardState();
}

class _EnableTeenLoginWizardState extends ConsumerState<EnableTeenLoginWizard> {
  final _credentialsKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Step _step = _Step.method;
  SupervisedLoginMethod _method = SupervisedLoginMethod.handle;
  bool _busy = false;
  String? _error;
  EnabledSupervisedLogin? _result;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  int get _stepNumber => _Step.values.indexOf(_step) + 1;

  void _go(_Step step) => setState(() {
        _step = step;
        _error = null;
      });

  void _back() {
    switch (_step) {
      case _Step.method:
        context.pop();
      case _Step.credentials:
        _go(_Step.method);
      case _Step.confirm:
        _go(_Step.credentials);
      case _Step.result:
        break;
    }
  }

  void _toCredentials() => _go(_Step.credentials);

  void _toConfirm() {
    if (_credentialsKey.currentState?.validate() != true) return;
    _go(_Step.confirm);
  }

  Future<void> _activate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(familyActionsProvider).enableSupervisedLogin(
          EnableSupervisedLoginParams(
            dependentId: widget.dependentId,
            method: _method,
            password: _password.text.trim(),
            email: _method == SupervisedLoginMethod.email
                ? _email.text.trim()
                : null,
          ),
        );
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _busy = false;
          _error = familyErrorMessage(failure);
          // Un correo ocupado o una contraseña rechazada se corrigen en el
          // paso de datos; el resto se reintenta desde la confirmación.
          if (_isCredentialsProblem(failure)) _step = _Step.credentials;
        });
      },
      (enabled) {
        // La contraseña ya no hace falta en memoria.
        _password.clear();
        _confirm.clear();
        setState(() {
          _busy = false;
          _result = enabled;
          _step = _Step.result;
        });
      },
    );
  }

  static bool _isCredentialsProblem(Failure failure) =>
      failure.errorCode == 'SUPERVISED_LOGIN_EMAIL_UNAVAILABLE' ||
      failure.errorCode == 'SUPERVISED_LOGIN_PASSWORD_INVALID';

  Future<void> _finish() async {
    // Activar el acceso termina "actuar por" este menor en el servidor: la app
    // sale del modo antes de volver a la lista, o la próxima petición con el
    // encabezado recibiría 403 ACTING_FOR_FORBIDDEN.
    final acting = ref.read(actingDependentProvider);
    if (acting?.userId == widget.dependentId) {
      await ref.read(authNotifierProvider.notifier).switchProfile(null);
      if (!mounted) return;
    }
    context.go(RouteNames.family);
  }

  Future<void> _copyHandle(String handle) async {
    await Clipboard.setData(ClipboardData(text: handle));
    if (!mounted) return;
    SacSnackBar.show(context, 'family.teen.wizard.copied'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final detail = ref.watch(dependentDetailProvider(widget.dependentId));

    return PopScope(
      // Tras activar, el único camino es "Listo": volver atrás repetiría un
      // paso que ya no existe.
      canPop: _step != _Step.result,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: SacTopBar(
          title: detail.maybeWhen(
            data: (d) => 'family.teen.wizard.title'
                .tr(namedArgs: {'name': d.summary.firstName}),
            orElse: () => 'family.access.title'.tr(),
          ),
          backgroundColor: c.background,
          foregroundColor: c.text,
        ),
        body: detail.when(
          // Activar el acceso invalida el detalle: sin esto el spinner taparía
          // la pantalla de resultado mientras se vuelve a leer.
          skipLoadingOnReload: true,
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                familyErrorMessage(error),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.textSecondary,
                    ),
              ),
            ),
          ),
          data: (data) {
            final name = data.summary.firstName;
            // Un menor sin edad mínima o que ya tiene acceso no pasa de aquí
            // (salvo que estemos en el resultado de haberlo activado).
            if (_step != _Step.result && !canEnableTeenLogin(data.summary)) {
              return _NotEligible(name: name);
            }
            return _buildStep(context, name);
          },
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, String name) {
    final hPad = Responsive.horizontalPadding(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
      children: [
        Text(
          'family.teen.wizard.step_of'.tr(namedArgs: {
            'current': '$_stepNumber',
            'total': '${_Step.values.length}',
          }),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.sac.textSecondary,
              ),
        ),
        const SizedBox(height: 4),
        switch (_step) {
          _Step.method => _MethodStep(
              name: name,
              method: _method,
              onChanged: (m) => setState(() => _method = m),
              onNext: _toCredentials,
              onBack: _back,
            ),
          _Step.credentials => _CredentialsStep(
              name: name,
              formKey: _credentialsKey,
              method: _method,
              email: _email,
              password: _password,
              confirm: _confirm,
              error: _error,
              onNext: _toConfirm,
              onBack: _back,
            ),
          _Step.confirm => _ConfirmStep(
              name: name,
              busy: _busy,
              error: _error,
              onActivate: _activate,
              onBack: _back,
            ),
          _Step.result => _ResultStep(
              name: name,
              result: _result!,
              onCopy: _copyHandle,
              onDone: _finish,
            ),
        },
      ],
    );
  }
}

class _NotEligible extends StatelessWidget {
  const _NotEligible({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'family.teen.wizard.not_eligible'.tr(namedArgs: {'name': name}),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.sac.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            SacButton.outline(
              text: 'common.back'.tr(),
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.sac.text,
            ),
      ),
    );
  }
}

class _MethodStep extends StatelessWidget {
  const _MethodStep({
    required this.name,
    required this.method,
    required this.onChanged,
    required this.onNext,
    required this.onBack,
  });

  final String name;
  final SupervisedLoginMethod method;
  final ValueChanged<SupervisedLoginMethod> onChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepTitle(
          'family.teen.wizard.method_title'.tr(namedArgs: {'name': name}),
        ),
        _MethodOption(
          key: const ValueKey('method_handle'),
          selected: method == SupervisedLoginMethod.handle,
          icon: HugeIcons.strokeRoundedUser,
          title: 'family.teen.wizard.method_handle'.tr(),
          hint: 'family.teen.wizard.method_handle_hint'
              .tr(namedArgs: {'name': name}),
          onTap: () => onChanged(SupervisedLoginMethod.handle),
        ),
        const SizedBox(height: 12),
        _MethodOption(
          key: const ValueKey('method_email'),
          selected: method == SupervisedLoginMethod.email,
          icon: HugeIcons.strokeRoundedMail01,
          title: 'family.teen.wizard.method_email'.tr(),
          hint: 'family.teen.wizard.method_email_hint'
              .tr(namedArgs: {'name': name}),
          onTap: () => onChanged(SupervisedLoginMethod.email),
        ),
        const SizedBox(height: 24),
        SacButton.primary(text: 'common.next'.tr(), onPressed: onNext),
        const SizedBox(height: 8),
        SacButton.ghost(text: 'common.back'.tr(), onPressed: onBack),
      ],
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final bool selected;
  final List<List<dynamic>> icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SacCard(
          borderColor: selected ? accent.color : null,
          backgroundColor: selected ? accent.light : null,
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                size: 24,
                color: selected ? accent.color : c.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: selected
                    ? HugeIcons.strokeRoundedCheckmarkCircle02
                    : HugeIcons.strokeRoundedCircle,
                size: 22,
                color: selected ? accent.color : c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CredentialsStep extends StatelessWidget {
  const _CredentialsStep({
    required this.name,
    required this.formKey,
    required this.method,
    required this.email,
    required this.password,
    required this.confirm,
    required this.error,
    required this.onNext,
    required this.onBack,
  });

  final String name;
  final GlobalKey<FormState> formKey;
  final SupervisedLoginMethod method;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirm;
  final String? error;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepTitle('family.teen.wizard.credentials_title'.tr()),
          if (method == SupervisedLoginMethod.email) ...[
            SacTextField(
              controller: email,
              label: 'auth.email_label'.tr(),
              hint:
                  'family.teen.wizard.email_hint'.tr(namedArgs: {'name': name}),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              prefixIcon: HugeIcons.strokeRoundedMail01,
              validator: Validators.validateEmail,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
          ],
          NewPasswordFields(
            passwordController: password,
            confirmController: confirm,
            onSubmitted: onNext,
          ),
          const SizedBox(height: 12),
          Text(
            'family.teen.wizard.password_note'.tr(namedArgs: {'name': name}),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            _InlineError(message: error!),
          ],
          const SizedBox(height: 24),
          SacButton.primary(text: 'common.next'.tr(), onPressed: onNext),
          const SizedBox(height: 8),
          SacButton.ghost(text: 'common.back'.tr(), onPressed: onBack),
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.name,
    required this.busy,
    required this.error,
    required this.onActivate,
    required this.onBack,
  });

  final String name;
  final bool busy;
  final String? error;
  final VoidCallback onActivate;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final args = {'name': name};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepTitle('family.teen.wizard.confirm_title'.tr()),
        _Warning(
          icon: HugeIcons.strokeRoundedUserSwitch,
          text: 'family.teen.wizard.warn_acting'.tr(namedArgs: args),
        ),
        _Warning(
          icon: HugeIcons.strokeRoundedSmartPhone01,
          text: 'family.teen.wizard.warn_devices'.tr(namedArgs: args),
        ),
        _Warning(
          icon: HugeIcons.strokeRoundedLockPassword,
          text: 'family.teen.wizard.warn_control'.tr(),
        ),
        _Warning(
          icon: HugeIcons.strokeRoundedView,
          text: 'family.teen.wizard.warn_privacy'.tr(),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          _InlineError(message: error!),
        ],
        const SizedBox(height: 24),
        SacButton.primary(
          text: 'family.teen.wizard.activate'.tr(),
          icon: HugeIcons.strokeRoundedTick02,
          isLoading: busy,
          onPressed: busy ? null : onActivate,
        ),
        const SizedBox(height: 8),
        SacButton.ghost(
          text: 'common.back'.tr(),
          onPressed: busy ? null : onBack,
        ),
      ],
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.icon, required this.text});

  final List<List<dynamic>> icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SacCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HugeIcon(
              icon: icon,
              size: 22,
              color: SacAccent.of(context).color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.text,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStep extends StatelessWidget {
  const _ResultStep({
    required this.name,
    required this.result,
    required this.onCopy,
    required this.onDone,
  });

  final String name;
  final EnabledSupervisedLogin result;
  final ValueChanged<String> onCopy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final login = result.supervisedLogin;
    final isHandle = login.method == SupervisedLoginMethod.handle;
    final identifier = (isHandle ? login.loginHandle : login.email) ?? '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            size: 48,
            color: SacAccent.of(context).color,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'family.teen.wizard.result_title'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
        ),
        const SizedBox(height: 16),
        SacCard(
          key: const ValueKey('wizard_result_identifier'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                (isHandle
                        ? 'family.teen.wizard.result_handle_label'
                        : 'family.teen.wizard.result_email_label')
                    .tr()
                    .toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                identifier,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
              ),
              if (isHandle && login.loginHandle != null) ...[
                const SizedBox(height: 12),
                SacButton.outline(
                  text: 'family.teen.wizard.copy'.tr(),
                  icon: HugeIcons.strokeRoundedCopy01,
                  onPressed: () => onCopy(login.loginHandle!),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'family.teen.wizard.result_hint'.tr(namedArgs: {'name': name}),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: c.textSecondary,
                height: 1.4,
              ),
        ),
        if (result.devicesRevoked > 0) ...[
          const SizedBox(height: 8),
          Text(
            'family.teen.wizard.result_devices'
                .tr(namedArgs: {'count': '${result.devicesRevoked}'}),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                ),
          ),
        ],
        const SizedBox(height: 24),
        SacButton.primary(
          text: 'family.teen.wizard.done'.tr(),
          onPressed: onDone,
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      key: const ValueKey('wizard_error'),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
