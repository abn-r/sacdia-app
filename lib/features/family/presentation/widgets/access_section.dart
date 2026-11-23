import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_list_row.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/dependent.dart';
import '../../domain/entities/supervised_login.dart';
import 'family_row.dart';

/// Sección "Acceso" del detalle de un menor (FP3-33), como grupo de filas.
///
/// Lo que ofrece depende del tutor y del menor:
/// - tutor SIN consentimiento verificado: las filas deshabilitadas y, debajo,
///   la razón (no puede activar, desactivar, restablecer ni ver el resumen);
/// - tutor verificado y menor sin acceso propio: "Darle acceso propio" si ya
///   alcanzó la edad mínima y la función está activa;
/// - con acceso propio: usuario (copiar), restablecer contraseña y desactivar
///   (en rojo); si está desactivado, reactivar;
/// - el resumen de actividad, siempre para un tutor verificado.
///
/// Es presentacional: cada acción es un callback que el detalle resuelve
/// (confirmaciones incluidas).
class AccessSection extends StatelessWidget {
  const AccessSection({
    super.key,
    required this.summary,
    required this.teenLoginEnabled,
    required this.busy,
    required this.onEnable,
    required this.onDisable,
    required this.onReactivate,
    required this.onResetPassword,
    required this.onOpenSummary,
    required this.onCopyHandle,
  });

  final DependentSummary summary;

  /// `family_features.teen_login` de `/auth/me`. Apagada, las acciones de
  /// gestión se ocultan (el servidor respondería 404 FAMILY_FEATURE_DISABLED).
  final bool teenLoginEnabled;
  final bool busy;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final VoidCallback onReactivate;
  final VoidCallback onResetPassword;
  final VoidCallback onOpenSummary;
  final ValueChanged<String> onCopyHandle;

  @override
  Widget build(BuildContext context) {
    final name = summary.firstName;
    final verified = summary.guardianship.isVerified;
    final login = summary.supervisedLogin;
    final hasOwnAccess = summary.accessMode == AccessMode.supervisedLogin;

    final badge = (hasOwnAccess || login != null)
        ? (login?.isDisabled ?? false)
            ? SacBadge.warning(label: 'family.access.disabled'.tr())
            : SacBadge.success(label: 'family.access.active'.tr())
        : const SizedBox.shrink();

    if (!verified) {
      return Column(
        key: const ValueKey('access_section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacGroupedSection(
            label: 'family.access.title'.tr(),
            action: badge,
            dividerIndent: 62,
            children: [
              SacListRow(
                leading: const SacListRowIcon(HugeIcons.strokeRoundedKey01),
                title: 'family.access.own_title'.tr(),
                enabled: false,
              ),
              SacListRow(
                leading: const SacListRowIcon(
                  HugeIcons.strokeRoundedChartLineData01,
                ),
                title: 'family.access.summary'.tr(),
                enabled: false,
              ),
            ],
          ),
          FamilyFootnote(
            key: const ValueKey('access_pending_guardian'),
            text:
                'family.access.pending_guardian'.tr(namedArgs: {'name': name}),
          ),
        ],
      );
    }

    final rows = <Widget>[
      ..._ownAccessRows(context),
      if (!summary.frozen)
        SacListRow(
          key: const ValueKey('access_summary'),
          leading: const SacListRowIcon(HugeIcons.strokeRoundedChartLineData01),
          title: 'family.access.summary'.tr(),
          onTap: onOpenSummary,
        ),
    ];

    return SacGroupedSection(
      key: const ValueKey('access_section'),
      label: 'family.access.title'.tr(),
      action: badge,
      dividerIndent: 62,
      children: rows,
    );
  }

  /// Estado del acceso propio y lo que se puede hacer con él.
  List<Widget> _ownAccessRows(BuildContext context) {
    final c = context.sac;
    final name = summary.firstName;
    final login = summary.supervisedLogin;
    final hasOwnAccess = summary.accessMode == AccessMode.supervisedLogin;

    // Sin acceso propio: ofrecer activarlo si ya cumplió la edad mínima.
    if (login == null && !hasOwnAccess) {
      if (!summary.ageMilestoneReached) {
        return [
          SacListRow(
            key: const ValueKey('access_not_yet'),
            leading: const SacListRowIcon(HugeIcons.strokeRoundedKey01),
            title: 'family.access.own_title'.tr(),
            subtitle: 'family.access.not_yet'.tr(namedArgs: {'name': name}),
          ),
        ];
      }
      if (summary.frozen || !teenLoginEnabled) {
        return [
          SacListRow(
            leading: const SacListRowIcon(HugeIcons.strokeRoundedKey01),
            title: 'family.access.own_title'.tr(),
            subtitle: 'family.access.none'.tr(),
          ),
        ];
      }
      return [
        // Cumplió la edad mínima de acceso propio (el aviso del cumpleaños):
        // el push `family:age_nudge` aterriza aquí.
        SacListRow(
          key: const ValueKey('age_nudge'),
          leading: const SacListRowIcon(HugeIcons.strokeRoundedBirthdayCake),
          title: 'family.age_nudge.title'.tr(namedArgs: {'name': name}),
          subtitle: 'family.age_nudge.body'.tr(),
        ),
        SacListRow(
          key: const ValueKey('access_enable'),
          leading: const SacListRowIcon(HugeIcons.strokeRoundedUserAdd01),
          title: 'family.access.enable'.tr(),
          titleColor: SacAccent.of(context).color,
          subtitle: 'family.access.enable_hint'.tr(namedArgs: {'name': name}),
          enabled: !busy,
          onTap: onEnable,
        ),
      ];
    }

    final handleRow = login == null ? null : _handleRow(context, login);

    // Con acceso propio (o que lo tuvo): la gestión la apaga la bandera.
    if (summary.frozen || !teenLoginEnabled) {
      return [if (handleRow != null) handleRow];
    }
    if (login?.isDisabled ?? false) {
      return [
        if (handleRow != null) handleRow,
        if (login!.canBeReactivated)
          SacListRow(
            key: const ValueKey('access_reactivate'),
            leading: const SacListRowIcon(HugeIcons.strokeRoundedRefresh),
            title: 'family.access.reactivate'.tr(),
            enabled: !busy,
            onTap: onReactivate,
          ),
      ];
    }
    return [
      if (handleRow != null) handleRow,
      SacListRow(
        key: const ValueKey('access_reset_password'),
        leading: const SacListRowIcon(HugeIcons.strokeRoundedLockPassword),
        title: 'family.access.reset_password'.tr(),
        enabled: !busy,
        onTap: onResetPassword,
      ),
      SacListRow(
        key: const ValueKey('access_disable'),
        leading: const SacListRowIcon(
          HugeIcons.strokeRoundedUserBlock01,
          destructive: true,
        ),
        title: 'family.access.disable'.tr(),
        titleColor: c.onErrorContainer,
        showChevron: false,
        enabled: !busy,
        onTap: onDisable,
      ),
    ];
  }

  /// Cómo entra el menor: su usuario (con copiar) o su correo.
  Widget _handleRow(BuildContext context, SupervisedLoginInfo login) {
    final isHandle = login.method == SupervisedLoginMethod.handle;
    final handle = login.loginHandle;
    final method = (isHandle
            ? 'family.access.method_handle'
            : 'family.access.method_email')
        .tr();
    if (!isHandle || handle == null) {
      return SacListRow(
        leading: const SacListRowIcon(HugeIcons.strokeRoundedKey01),
        title: 'family.access.own_title'.tr(),
        subtitle: method,
      );
    }
    return SacListRow(
      key: const ValueKey('access_handle'),
      leading: const SacListRowIcon(HugeIcons.strokeRoundedUser),
      title: handle,
      subtitle: '${'family.access.own_title'.tr()} · $method',
      trailing: IconButton(
        tooltip: 'family.access.copy'.tr(),
        onPressed: () => onCopyHandle(handle),
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedCopy01,
          size: 20,
          color: SacAccent.of(context).color,
        ),
      ),
    );
  }
}
