import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../biometric/presentation/widgets/biometric_settings_section.dart';
import '../utils/change_password_flow.dart';
import '../widgets/security_sessions_section.dart';

/// Seguridad: password, biometric unlock and open sessions in one screen.
///
/// What each mode sees (same rules Settings always had):
/// - password: everyone except while acting for a minor (teens do see it);
/// - biometric unlock: always (it is a setting of this phone);
/// - open sessions: not while acting and not a supervised teen.
class SecurityView extends ConsumerWidget {
  const SecurityView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acting = ref.watch(actingDependentProvider) != null;
    final teen = ref.watch(
      authNotifierProvider.select((v) => v.value?.isLimitedAccount ?? false),
    );
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'settings.security_title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            final bar = SacTopBar.frostedInset(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                bar + 8,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                SacSettingsGroup(
                  children: [
                    if (!acting) ...[
                      SacSettingsTile(
                        key: const ValueKey('security-password'),
                        icon: HugeIcons.strokeRoundedLockPassword,
                        title: 'settings.security.password'.tr(),
                        onTap: () => runChangePasswordFlow(context, ref),
                      ),
                      const SacSettingsDivider(),
                    ],
                    const BiometricSettingsSection(),
                  ],
                ),
                if (!acting && !teen) ...[
                  const SizedBox(height: 24),
                  const SecuritySessionsSection(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
