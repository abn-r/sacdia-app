import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'profile_switcher_sheet.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Entrada "Mi familia" (y "Cambiar de perfil" si hay menores) del perfil.
///
/// No dibuja nada mientras se actúa por un dependiente (FP-57): Mi familia se
/// gestiona desde el perfil propio del tutor.
class FamilyProfileEntry extends ConsumerWidget {
  const FamilyProfileEntry({super.key, required this.horizontalPadding});

  final double horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(actingDependentProvider) != null) {
      return const SizedBox.shrink();
    }
    // Un adolescente supervisado, una cuenta sin fecha de nacimiento o una
    // cuenta desconocida no tienen Mi familia ni selector de perfiles (FP3-32):
    // el router también bloquea /family.
    final isTeen = ref.watch(
      authNotifierProvider.select((v) => v.value?.isLimitedAccount ?? false),
    );
    if (isTeen) return const SizedBox.shrink();
    final c = context.sac;
    final family = ref.watch(authNotifierProvider).value?.family;
    final count = family?.dependentsCount ?? 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 0),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: c.border, width: 1),
        ),
        child: Column(
          children: [
            SacSettingsTile(
              icon: HugeIcons.strokeRoundedUserGroup,
              title: 'family.profile.entry_title'.tr(),
              subtitle: count > 0
                  ? 'family.profile.entry_count'.plural(count, name: 'count')
                  : 'family.profile.entry_subtitle'.tr(),
              onTap: () => context.push(RouteNames.family),
            ),
            if (count > 0) ...[
              Divider(
                height: 1,
                thickness: 1,
                indent: 60,
                color: c.borderLight,
              ),
              SacSettingsTile(
                icon: HugeIcons.strokeRoundedUserSwitch,
                title: 'family.profile.switch_title'.tr(),
                subtitle: 'family.profile.switch_subtitle'.tr(),
                onTap: () => showProfileSwitcherSheet(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
