import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/biometric_provider.dart';

/// Diálogo modal para confirmar acciones sensibles mediante biometría.
///
/// Útil cuando queremos un paso UI explícito (título + descripción) antes
/// del prompt del SO — típicamente en flows destructivos (borrar cuenta,
/// exportar datos, revocar sesiones).
///
/// Si biometría está OFF → cierra inmediatamente con `true` (bypass).
///
/// Uso:
/// ```dart
/// final ok = await showConfirmBiometricDialog(
///   context,
///   ref,
///   title: 'Borrar cuenta',
///   description: 'Esta acción es irreversible.',
///   reason: 'biometric.confirm_delete_account'.tr(),
/// );
/// if (ok != true) return;
/// ```
Future<bool?> showConfirmBiometricDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String description,
  required String reason,
}) async {
  final enabled = ref.read(biometricProvider).enabled;
  if (!enabled) return true;

  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _ConfirmBiometricDialog(
      title: title,
      description: description,
      reason: reason,
    ),
  );
}

class _ConfirmBiometricDialog extends ConsumerStatefulWidget {
  final String title;
  final String description;
  final String reason;

  const _ConfirmBiometricDialog({
    required this.title,
    required this.description,
    required this.reason,
  });

  @override
  ConsumerState<_ConfirmBiometricDialog> createState() =>
      _ConfirmBiometricDialogState();
}

class _ConfirmBiometricDialogState
    extends ConsumerState<_ConfirmBiometricDialog> {
  bool _busy = false;

  Future<void> _authenticate() async {
    if (_busy) return;
    setState(() => _busy = true);
    final notifier = ref.read(biometricProvider.notifier);
    final ok = await notifier.authenticate(reason: widget.reason);
    if (!mounted) return;
    Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedFingerPrint,
            color: AppColors.primary,
            size: 28,
          ),
        ),
      ),
      title: Text(widget.title, textAlign: TextAlign.center),
      content: Text(widget.description, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _busy ? null : _authenticate,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('biometric.authenticate_cta'.tr()),
        ),
      ],
    );
  }
}
