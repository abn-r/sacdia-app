import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_list_row.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/dependent.dart';
import '../../domain/entities/linked_device.dart';
import '../family_error_messages.dart';
import '../providers/linked_devices_providers.dart';
import 'family_row.dart';
import 'family_sheets.dart';

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

/// Sección «Teléfonos vinculados» del detalle de un menor (FP3-41, FP3-49),
/// como grupo de filas: cada teléfono (nombre, plataforma, última actividad,
/// quién lo vinculó) con «Desvincular», y «Vincular un teléfono». Los
/// desvinculados van en su propio grupo.
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
    final confirmed = await showFamilyConfirmSheet(
      context,
      title:
          'family.devices.revoke_title'.tr(namedArgs: {'label': device.label}),
      body: 'family.devices.revoke_body'
          .tr(namedArgs: {'name': summary.firstName}),
      confirmLabel: 'family.devices.revoke_confirm'.tr(),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
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
    final devices = ref.watch(linkedDevicesProvider(summary.userId));
    final data = devices.value;
    final activeCount = data?.active.length ?? summary.linkedDevicesCount;
    final full = data?.isFull ?? false;
    final countStyle = TextStyle(
      fontSize: SacFontSize.labelSmall,
      fontWeight: FontWeight.w600,
      color: c.textTertiary,
    );

    final rows = devices.when<List<Widget>>(
      loading: () => const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: SacLoadingSmall()),
        ),
      ],
      error: (error, _) => [
        SacListRow(
          key: const ValueKey('devices_error'),
          leading: const SacListRowIcon(
            HugeIcons.strokeRoundedAlert02,
            destructive: true,
          ),
          title: familyErrorMessage(error),
          subtitle: 'common.retry'.tr(),
          onTap: () => ref.invalidate(linkedDevicesProvider(summary.userId)),
        ),
      ],
      data: (list) => [
        if (list.active.isEmpty)
          SacListRow(
            key: const ValueKey('devices_empty'),
            leading: const SacListRowIcon(HugeIcons.strokeRoundedSmartPhone01),
            title: 'family.devices.empty'.tr(),
            titleColor: c.textSecondary,
          ),
        for (final device in list.active)
          _DeviceRow(
            device: device,
            onRevoke: () => _revoke(context, ref, device),
          ),
      ],
    );

    return Column(
      key: const ValueKey('devices_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacGroupedSection(
          label: 'family.devices.title'.tr(),
          dividerIndent: 62,
          action: activeCount > 0
              ? Text(
                  data == null
                      ? '$activeCount'
                      : '$activeCount/${data.maxDevices}',
                  style: countStyle,
                )
              : const SizedBox.shrink(),
          children: [
            ...rows,
            if (summary.canPairDevice)
              SacListRow(
                key: const ValueKey('devices_pair'),
                leading: const SacListRowIcon(HugeIcons.strokeRoundedQrCode),
                title: 'family.devices.pair'.tr(),
                titleColor: full ? null : SacAccent.of(context).color,
                enabled: !full,
                onTap: onPair,
              ),
          ],
        ),
        if (summary.canPairDevice && full)
          FamilyFootnote(
            key: const ValueKey('devices_limit_hint'),
            text: 'family.devices.limit_hint'.tr(namedArgs: {
              'max': '${data?.maxDevices ?? kDefaultMaxLinkedDevices}',
            }),
          )
        else
          FamilyFootnote(
            key: const ValueKey('devices_intro'),
            text: (summary.canPairDevice
                    ? 'family.devices.intro'
                    : 'family.devices.no_new')
                .tr(namedArgs: {'name': summary.firstName}),
          ),
        if (data != null && data.revoked.isNotEmpty)
          SacGroupedSection(
            key: const ValueKey('devices_history'),
            label: 'family.devices.history'.tr(),
            dividerIndent: 62,
            children: [
              for (final device in data.revoked) _DeviceRow(device: device),
            ],
          ),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, this.onRevoke});

  final LinkedDevice device;

  /// Nulo en un teléfono ya desvinculado (solo historial).
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
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
    final onRevoke = this.onRevoke;
    return SacListRow(
      key: ValueKey('device_${device.id}'),
      leading: const SacListRowIcon(HugeIcons.strokeRoundedSmartPhone01),
      title: device.label,
      titleColor: device.isRevoked ? c.textTertiary : null,
      subtitle: details.join(' · '),
      trailing: onRevoke == null
          ? null
          : TextButton(
              key: ValueKey('device_revoke_${device.id}'),
              style: TextButton.styleFrom(
                foregroundColor: c.onErrorContainer,
                minimumSize: const Size(44, 44),
              ),
              onPressed: onRevoke,
              child: Text(
                'family.devices.revoke'.tr(),
                style: const TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }
}
