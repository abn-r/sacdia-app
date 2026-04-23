import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/setting_tile.dart';
import '../providers/biometric_provider.dart';

/// Toggle de biometría expuesto para insertar en `settings_view`.
///
/// Renderiza un [SettingTile] con un [Switch] que:
/// - OFF → ON: dispara prompt biométrico para "enrolar" y persiste opt-in.
/// - ON  → OFF: desactiva y limpia settings.
///
/// Si el dispositivo no soporta biometría o no tiene factores enrolados,
/// el tile se renderea pero el switch queda deshabilitado con subtítulo
/// explicativo.
class BiometricSettingsSection extends ConsumerWidget {
  const BiometricSettingsSection({super.key});

  Future<void> _onToggle(
    BuildContext context,
    WidgetRef ref,
    bool newValue,
  ) async {
    final notifier = ref.read(biometricProvider.notifier);
    if (!newValue) {
      await notifier.disable();
      return;
    }
    final result = await notifier.enable(
      reason: 'biometric.enroll_reason'.tr(),
    );
    if (!context.mounted) return;
    switch (result) {
      case BiometricEnableResult.ok:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('biometric.enabled_success'.tr())),
        );
        break;
      case BiometricEnableResult.notSupported:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('biometric.device_not_supported'.tr())),
        );
        break;
      case BiometricEnableResult.noneEnrolled:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('biometric.no_biometric_enrolled'.tr())),
        );
        break;
      case BiometricEnableResult.authFailed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('biometric.auth_failed'.tr())),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(biometricProvider);
    final capAsync = ref.watch(biometricCapabilityProvider);

    final capability = capAsync.asData?.value;
    final isLoading = capAsync.isLoading;
    final canEnable = capability?.canEnable ?? false;

    String? subtitle;
    if (!isLoading && capability != null) {
      if (!capability.deviceSupportsBiometric) {
        subtitle = 'biometric.device_not_supported'.tr();
      } else if (!capability.hasEnrolledBiometrics) {
        subtitle = 'biometric.no_biometric_enrolled'.tr();
      }
    }

    final switchEnabled = canEnable || state.enabled;

    return SettingTile(
      icon: HugeIcons.strokeRoundedFingerPrint,
      title: 'biometric.tile_title'.tr(),
      subtitle: subtitle,
      iconColor: AppColors.primary,
      trailing: Switch.adaptive(
        value: state.enabled,
        onChanged: switchEnabled
            ? (v) => _onToggle(context, ref, v)
            : null,
      ),
    );
  }
}
