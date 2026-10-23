import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../domain/entities/dependent.dart';
import '../../domain/entities/linked_device.dart';
import '../family_error_messages.dart';
import '../providers/linked_devices_providers.dart';

/// ¿Se muestra la sección «Teléfonos vinculados» de un menor?
///
/// - Apagada la bandera `family_features.linked_device` (o desconocida): NO
///   (falla cerrado; el servidor respondería 404 `FAMILY_FEATURE_DISABLED`).
/// - Solo para un tutor con el consentimiento verificado y un menor sin congelar.
/// - Se ofrece mientras se pueda vincular uno nuevo ([DependentSummary
///   .canPairDevice]) o aún haya teléfonos que gestionar: a los 13 años o con
///   acceso propio no se vinculan nuevos, pero los existentes siguen visibles
///   para desvincularlos.
bool shouldShowDevicesSection(
  DependentSummary summary, {
  required bool featureEnabled,
}) {
  if (!featureEnabled) return false;
  if (!summary.guardianship.isVerified || summary.frozen) return false;
  return summary.canPairDevice || summary.linkedDevicesCount > 0;
}

/// Sección «Teléfonos vinculados» del detalle de un menor (FP3-41, FP3-49):
/// lista (nombre, plataforma, última actividad, quién lo vinculó), desvincular
/// con confirmación y «Vincular un teléfono».
class DevicesSection extends ConsumerWidget {
  const DevicesSection({
    super.key,
    required this.summary,
    required this.onPair,
  });

  final DependentSummary summary;

  /// Abre la pantalla del QR.
  final VoidCallback onPair;

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    LinkedDevice device,
  ) async {
    final confirmed = await SacDialog.show(
      context,
      title:
          'family.devices.revoke_title'.tr(namedArgs: {'label': device.label}),
      content: 'family.devices.revoke_body'
          .tr(namedArgs: {'name': summary.firstName}),
      confirmLabel: 'family.devices.revoke_confirm'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(linkedDevicesActionsProvider)
        .revoke(summary.userId, device.id);
    result.fold(
      (failure) => SacSnackBar.showMessenger(
        messenger,
        familyErrorMessage(failure),
        isError: true,
      ),
      (_) => SacSnackBar.showMessenger(
        messenger,
        'family.devices.revoked_toast'.tr(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final devices = ref.watch(linkedDevicesProvider(summary.userId));
    final data = devices.valueOrNull;
    final activeCount = data?.active.length ?? summary.linkedDevicesCount;
    final full = data?.isFull ?? false;

    return SacCard(
      key: const ValueKey('devices_section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'family.devices.title'.tr(),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              if (activeCount > 0)
                SacBadge.success(
                  label: data == null
                      ? '$activeCount'
                      : '$activeCount/${data.maxDevices}',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (summary.canPairDevice
                    ? 'family.devices.intro'
                    : 'family.devices.no_new')
                .tr(namedArgs: {'name': summary.firstName}),
            key: const ValueKey('devices_intro'),
            style: textTheme.bodySmall?.copyWith(
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          devices.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: SacLoadingSmall()),
            ),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  familyErrorMessage(error),
                  key: const ValueKey('devices_error'),
                  style: textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
                const SizedBox(height: 8),
                SacButton.ghost(
                  text: 'common.retry'.tr(),
                  icon: HugeIcons.strokeRoundedRefresh,
                  onPressed: () =>
                      ref.invalidate(linkedDevicesProvider(summary.userId)),
                ),
              ],
            ),
            data: (list) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (list.active.isEmpty)
                  Text(
                    'family.devices.empty'.tr(),
                    key: const ValueKey('devices_empty'),
                    style: textTheme.bodySmall?.copyWith(color: c.textTertiary),
                  ),
                for (final device in list.active)
                  _DeviceTile(
                    device: device,
                    onRevoke: () => _revoke(context, ref, device),
                  ),
                if (list.revoked.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'family.devices.history'.tr(),
                    style: textTheme.labelMedium?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  for (final device in list.revoked)
                    _DeviceTile(device: device),
                ],
              ],
            ),
          ),
          if (summary.canPairDevice) ...[
            const SizedBox(height: 12),
            if (full)
              Text(
                'family.devices.limit_hint'.tr(namedArgs: {
                  'max': '${data?.maxDevices ?? kDefaultMaxLinkedDevices}',
                }),
                key: const ValueKey('devices_limit_hint'),
                style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
              ),
            const SizedBox(height: 8),
            SacButton.primary(
              key: const ValueKey('devices_pair'),
              text: 'family.devices.pair'.tr(),
              icon: HugeIcons.strokeRoundedQrCode,
              onPressed: full ? null : onPair,
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, this.onRevoke});

  final LinkedDevice device;

  /// Nulo en un teléfono ya desvinculado (solo historial).
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final locale = context.locale.toString();
    final seen = device.lastSeenAt;
    final details = <String>[
      if (device.platform == 'ios')
        'iOS'
      else if (device.platform == 'android')
        'Android',
      if (device.pairedByDisplayName != null)
        'family.devices.paired_by'
            .tr(namedArgs: {'name': device.pairedByDisplayName!}),
      if (device.isRevoked)
        'family.devices.revoked_on'.tr(namedArgs: {
          'date': DateFormat.yMMMd(locale).format(device.revokedAt!.toLocal()),
        })
      else
        seen == null
            ? 'family.devices.never_seen'.tr()
            : 'family.devices.last_seen'.tr(namedArgs: {
                'when':
                    DateFormat.yMMMd(locale).add_jm().format(seen.toLocal()),
              }),
    ];
    return Padding(
      key: ValueKey('device_${device.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSmartPhone01,
            size: 24,
            color: device.isRevoked ? c.textTertiary : c.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: device.isRevoked ? c.textTertiary : c.text,
                  ),
                ),
                Text(
                  details.join(' · '),
                  style: textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onRevoke != null)
            TextButton(
              key: ValueKey('device_revoke_${device.id}'),
              onPressed: onRevoke,
              child: Text(
                'family.devices.revoke'.tr(),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }
}
