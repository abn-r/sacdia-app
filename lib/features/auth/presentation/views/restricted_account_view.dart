import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../providers/auth_providers.dart';

/// Destino de una cuenta cuyo principal la app no reconoce (servidor más nuevo
/// que la app). Falla cerrado: no se trata como adulto ni se piden datos; solo
/// se explica y se ofrece cerrar sesión.
class RestrictedAccountView extends ConsumerWidget {
  const RestrictedAccountView({super.key});

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
                constraints: const BoxConstraints(
                  maxWidth: Responsive.maxFormWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedUserLock01,
                        size: 44,
                        color: SacAccent.of(context).color,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'restricted_account.title'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'restricted_account.body'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: c.textSecondary,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 24),
                    SacButton.ghost(
                      text: 'legal_gate.sign_out'.tr(),
                      icon: HugeIcons.strokeRoundedLogout02,
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
