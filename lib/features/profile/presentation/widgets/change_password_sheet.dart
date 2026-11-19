import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/validators.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../biometric/presentation/providers/biometric_provider.dart';
import '../utils/password_rules.dart';

/// Bottom sheet to change the password: current one, new one with its rules
/// lighting up as they are met, and no "confirm" field (the eye reveals it).
///
/// Confirms with biometrics when they are on, then `POST /auth/update-password`.
/// Errors stay inside the sheet. Closes with `true` once the password changed.
class ChangePasswordSheet extends ConsumerStatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  ConsumerState<ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final current = _currentCtrl.text.trim();
    final next = _newCtrl.text.trim();

    if (current.isEmpty || next.isEmpty) {
      setState(() => _error = 'profile.settings.error_fill_all'.tr());
      return;
    }
    // Same policy as sign-up and the backend.
    final policyError = Validators.validatePassword(next);
    if (policyError != null) {
      setState(() => _error = policyError);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    // Biometric confirmation (no-op when biometrics are off).
    final bioOk = await requireBiometricConfirmation(
      context,
      ref,
      reason: 'biometric.confirm_sensitive_action'.tr(),
    );
    if (!mounted) return;
    if (!bioOk) {
      setState(() {
        _isSaving = false;
        _error = 'profile.settings.operation_cancelled'.tr();
      });
      return;
    }

    final error = await ref.read(authNotifierProvider.notifier).updatePassword(
          currentPassword: current,
          newPassword: next,
        );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSaving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SacSheetHeader(
                title: 'profile.settings.change_password_dialog_title'.tr(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SacTextField(
                      key: const ValueKey('password-current'),
                      controller: _currentCtrl,
                      label: 'profile.settings.field_current_password'.tr(),
                      obscureText: true,
                      enabled: !_isSaving,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: 14),
                    SacTextField(
                      key: const ValueKey('password-new'),
                      controller: _newCtrl,
                      label: 'profile.settings.field_new_password'.tr(),
                      obscureText: true,
                      enabled: !_isSaving,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      // Rules react to every keystroke.
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: 10),
                    for (final rule in PasswordRule.values)
                      _RuleRow(
                        rule: rule,
                        met: isPasswordRuleMet(rule, _newCtrl.text),
                      ),
                    AnimatedSize(
                      duration: SacMotion.reduceMotionOf(context)
                          ? Duration.zero
                          : SacMotion.standard,
                      curve: SacMotion.easeOut,
                      alignment: Alignment.topCenter,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _error!,
                                key: const ValueKey('password-error'),
                                style: TextStyle(
                                  fontSize: SacFontSize.bodyMedium,
                                  fontWeight: FontWeight.w500,
                                  color: c.error,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: SacButton.primary(
                  text: 'settings.password_sheet.submit'.tr(),
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.met});

  final PasswordRule rule;
  final bool met;

  String _label() => switch (rule) {
        PasswordRule.length => 'settings.password_sheet.rule_length'.tr(
            namedArgs: {'count': '${Validators.newPasswordMinLength}'},
          ),
        PasswordRule.letters => 'settings.password_sheet.rule_letters'.tr(),
        PasswordRule.number => 'settings.password_sheet.rule_number'.tr(),
        PasswordRule.special => 'settings.password_sheet.rule_special'.tr(
            namedArgs: {
              'chars': Validators.newPasswordSpecialChars.split('').join(' '),
            },
          ),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final color = met ? c.onSuccessContainer : c.textTertiary;
    final label = _label();
    return Semantics(
      container: true,
      label: label,
      value: met
          ? 'settings.password_sheet.rule_met'.tr()
          : 'settings.password_sheet.rule_unmet'.tr(),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 2, top: 4),
        child: Row(
          children: [
            HugeIcon(
              icon: met
                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                  : HugeIcons.strokeRoundedCircle,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  color: color,
                  fontWeight: met ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
