import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_dialog.dart';
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
    barrierColor: context.sac.barrierColor,
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
    return SacDialog(
      title: widget.title,
      content: widget.description,
      icon: HugeIcons.strokeRoundedFingerPrint,
      iconColor: AppColors.primary,
      iconBackgroundColor: AppColors.primary.withValues(alpha: 0.12),
      actions: [
        SacDialogAction(
          label: 'common.cancel'.tr(),
          style: SacDialogActionStyle.cancel,
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
        SacDialogAction(
          label: 'biometric.authenticate_cta'.tr(),
          isLoading: _busy,
          onPressed: _busy ? null : _authenticate,
        ),
      ],
    );
  }
}
