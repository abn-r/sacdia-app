import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/accent_provider.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../../accessibility/presentation/providers/accessibility_provider.dart';
import '../widgets/appearance_accent_swatches.dart';
import '../widgets/appearance_text_card.dart';
import '../widgets/appearance_theme_cards.dart';

/// Appearance in one screen: theme, accent color, text size, high contrast and
/// reduced motion. Every change applies at once.
class AppearanceView extends ConsumerWidget {
  const AppearanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final accent = ref.watch(accentNotifierProvider);
    final settings = ref.watch(accessibilityProvider);
    final a11y = ref.read(accessibilityProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'settings.appearance_title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            final bar = SacTopBar.frostedInset(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(16, bar + 8, 16, 8),
              children: [
                AppearanceEyebrow(
                  title: 'settings.appearance.section_theme'.tr(),
                ),
                const AppearanceThemeCards(),
                const SizedBox(height: 24),
                AppearanceEyebrow(
                  title: 'settings.appearance.section_accent'.tr(),
                  trailing: accent.labelKey.tr(),
                ),
                const AppearanceAccentSwatches(),
                const SizedBox(height: 24),
                AppearanceEyebrow(
                  title: 'settings.appearance.section_text'.tr(),
                ),
                const AppearanceTextCard(),
                const SizedBox(height: 16),
                SacSettingsGroup(
                  children: [
                    SacSettingsSwitchTile(
                      icon: HugeIcons.strokeRoundedMoonEclipse,
                      title: 'accessibility.high_contrast_tile'.tr(),
                      value: settings.highContrast,
                      onChanged: a11y.setHighContrast,
                    ),
                    const SacSettingsDivider(),
                    SacSettingsSwitchTile(
                      icon: HugeIcons.strokeRoundedPause,
                      title: 'accessibility.reduce_motion_tile'.tr(),
                      value: settings.reduceMotion,
                      onChanged: a11y.setReduceMotion,
                    ),
                  ],
                ),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            );
          },
        ),
      ),
    );
  }
}
