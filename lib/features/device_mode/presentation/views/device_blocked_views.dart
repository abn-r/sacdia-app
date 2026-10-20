import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Términos nuevos sin aceptar: el teléfono NO puede aceptarlos (no tiene
/// `legal:accept`); su tutor lo hace desde su propio teléfono actuando por el
/// menor. Mientras tanto no se usa nada más (FP3-28, FP3-52).
class DeviceLegalBlockView extends ConsumerWidget {
  const DeviceLegalBlockView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BlockedScaffold(
      icon: HugeIcons.strokeRoundedLegalDocument01,
      titleKey: 'device.legal_block.title',
      bodyKey: 'device.legal_block.body',
      primary: SacButton.primary(
        key: const ValueKey('device_legal_refresh'),
        text: 'device.legal_block.refresh'.tr(),
        icon: HugeIcons.strokeRoundedRefresh,
        onPressed: () => ref
            .read(authNotifierProvider.notifier)
            .refreshCurrentUser(keepCurrentOnFailure: true),
      ),
    );
  }
}

/// Registro del menor incompleto: el teléfono nunca entra al post-registro; su
/// tutor lo termina desde su teléfono.
class DeviceRegistrationPendingView extends ConsumerWidget {
  const DeviceRegistrationPendingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BlockedScaffold(
      icon: HugeIcons.strokeRoundedUserEdit01,
      titleKey: 'device.registration_pending.title',
      bodyKey: 'device.registration_pending.body',
      primary: SacButton.primary(
        key: const ValueKey('device_registration_refresh'),
        text: 'device.registration_pending.refresh'.tr(),
        icon: HugeIcons.strokeRoundedRefresh,
        onPressed: () => ref
            .read(authNotifierProvider.notifier)
            .refreshCurrentUser(keepCurrentOnFailure: true),
      ),
    );
  }
}

class _BlockedScaffold extends ConsumerWidget {
  const _BlockedScaffold({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
    required this.primary,
  });

  final HugeIconData icon;
  final String titleKey;
  final String bodyKey;
  final Widget primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: Responsive.formPadding(context),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: Responsive.maxFormWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: HugeIcon(
                        icon: icon,
                        size: 44,
                        color: SacAccent.of(context).color,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      titleKey.tr(),
                      key: const ValueKey('device_blocked_title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bodyKey.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: c.textSecondary,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 24),
                    primary,
                    const SizedBox(height: 8),
                    SacButton.ghost(
                      key: const ValueKey('device_blocked_unlink'),
                      text: 'device.home.unlink'.tr(),
                      icon: HugeIcons.strokeRoundedLinkBackward,
                      textColor: AppColors.error,
                      onPressed: () =>
                          ref.read(authNotifierProvider.notifier).signOut(),
                    ),
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
