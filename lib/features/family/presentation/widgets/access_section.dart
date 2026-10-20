import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../domain/entities/dependent.dart';
import '../../domain/entities/supervised_login.dart';

/// Sección "Acceso" del detalle de un menor (FP3-33).
///
/// Lo que ofrece depende del tutor y del menor:
/// - tutor SIN consentimiento verificado: solo el estado, con la explicación
///   (no puede activar, desactivar, restablecer ni ver el resumen);
/// - tutor verificado y menor sin acceso propio: "Darle acceso propio" si ya
///   alcanzó la edad mínima y la función está activa;
/// - con acceso propio: estado, usuario (copiar), restablecer contraseña y
///   desactivar; si está desactivado, reactivar;
/// - el resumen de progreso, siempre para un tutor verificado.
///
/// Es presentacional: cada acción es un callback que el detalle resuelve
/// (diálogos de advertencia incluidos).
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
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final name = summary.firstName;
    final verified = summary.guardianship.isVerified;
    final login = summary.supervisedLogin;
    final hasOwnAccess = summary.accessMode == AccessMode.supervisedLogin;

    return SacCard(
      key: const ValueKey('access_section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'family.access.title'.tr(),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              if (hasOwnAccess || login != null)
                login?.isDisabled ?? false
                    ? SacBadge.warning(label: 'family.access.disabled'.tr())
                    : SacBadge.success(label: 'family.access.active'.tr()),
            ],
          ),
          if (!verified) ...[
            const SizedBox(height: 8),
            Text(
              'family.access.pending_guardian'.tr(namedArgs: {'name': name}),
              key: const ValueKey('access_pending_guardian'),
              style: textTheme.bodySmall?.copyWith(
                color: c.textSecondary,
                height: 1.4,
              ),
            ),
          ] else ...[
            if (login != null) ...[
              const SizedBox(height: 8),
              _LoginRow(login: login, onCopy: onCopyHandle),
            ],
            ..._actions(context, verified: verified),
          ],
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, {required bool verified}) {
    if (summary.frozen) return const [];
    return [
      ..._managementActions(context),
      // El resumen funciona en todos los modos de acceso para un tutor
      // verificado y no depende de la bandera del acceso propio.
      const SizedBox(height: 8),
      SacButton.outline(
        text: 'family.access.summary'.tr(),
        icon: HugeIcons.strokeRoundedChartLineData01,
        onPressed: onOpenSummary,
      ),
    ];
  }

  /// Activar / reactivar / restablecer / desactivar, según el estado del acceso.
  List<Widget> _managementActions(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final name = summary.firstName;
    final login = summary.supervisedLogin;
    final hasOwnAccess = summary.accessMode == AccessMode.supervisedLogin;

    // Sin acceso propio: ofrecer activarlo si ya cumplió la edad mínima.
    if (login == null && !hasOwnAccess) {
      if (!summary.ageMilestoneReached) {
        return [
          const SizedBox(height: 8),
          Text(
            'family.access.not_yet'.tr(namedArgs: {'name': name}),
            key: const ValueKey('access_not_yet'),
            style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ];
      }
      if (!teenLoginEnabled) return const [];
      return [
        const SizedBox(height: 8),
        // Cumplió la edad mínima de acceso propio (el aviso del cumpleaños):
        // el push `family:age_nudge` aterriza aquí.
        _AgeNudge(name: name),
        const SizedBox(height: 8),
        Text(
          'family.access.enable_hint'.tr(namedArgs: {'name': name}),
          style: textTheme.bodySmall?.copyWith(
            color: c.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        SacButton.primary(
          text: 'family.access.enable'.tr(),
          icon: HugeIcons.strokeRoundedUserAdd01,
          onPressed: busy ? null : onEnable,
        ),
      ];
    }

    // Con acceso propio (o que lo tuvo): la gestión la apaga la bandera.
    if (!teenLoginEnabled) return const [];
    if (login?.isDisabled ?? false) {
      if (!login!.canBeReactivated) return const [];
      return [
        const SizedBox(height: 12),
        SacButton.primary(
          text: 'family.access.reactivate'.tr(),
          icon: HugeIcons.strokeRoundedRefresh,
          onPressed: busy ? null : onReactivate,
        ),
      ];
    }
    return [
      const SizedBox(height: 12),
      SacButton.outline(
        text: 'family.access.reset_password'.tr(),
        icon: HugeIcons.strokeRoundedLockPassword,
        onPressed: busy ? null : onResetPassword,
      ),
      const SizedBox(height: 8),
      SacButton.ghost(
        text: 'family.access.disable'.tr(),
        icon: HugeIcons.strokeRoundedUserBlock01,
        textColor: AppColors.error,
        onPressed: busy ? null : onDisable,
      ),
    ];
  }
}

/// Aviso de que el menor ya cumplió la edad mínima de acceso propio.
class _AgeNudge extends StatelessWidget {
  const _AgeNudge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('age_nudge'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedBirthdayCake,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'family.age_nudge.title'.tr(namedArgs: {'name': name}),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'family.age_nudge.body'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginRow extends StatelessWidget {
  const _LoginRow({required this.login, required this.onCopy});

  final SupervisedLoginInfo login;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final isHandle = login.method == SupervisedLoginMethod.handle;
    final handle = login.loginHandle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (isHandle
                  ? 'family.access.method_handle'
                  : 'family.access.method_email')
              .tr(),
          style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
        ),
        if (isHandle && handle != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  handle,
                  key: const ValueKey('access_handle'),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'family.access.copy'.tr(),
                onPressed: () => onCopy(handle),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedCopy01,
                  size: 20,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
