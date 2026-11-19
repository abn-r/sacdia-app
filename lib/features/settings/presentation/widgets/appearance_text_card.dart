import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../../accessibility/domain/entities/accessibility_settings.dart';
import '../../../accessibility/presentation/providers/accessibility_provider.dart';

/// Text size: a real sentence drawn at the chosen size and a slider over the
/// accessibility presets (system, normal, large, extra large).
///
/// The sample is drawn with the scaler switched off and its font size animated
/// (`AnimatedDefaultTextStyle`), so it grows smoothly while the slider moves.
class AppearanceTextCard extends ConsumerWidget {
  const AppearanceTextCard({super.key});

  static const _options = TextSizeOption.values;

  static String labelFor(TextSizeOption option) => switch (option) {
        TextSizeOption.system => 'accessibility.text_size_system'.tr(),
        TextSizeOption.normal => 'accessibility.text_size_normal'.tr(),
        TextSizeOption.large => 'accessibility.text_size_large'.tr(),
        TextSizeOption.extraLarge => 'accessibility.text_size_extra_large'.tr(),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    final option = ref.watch(accessibilityProvider.select((s) => s.textSize));
    final notifier = ref.read(accessibilityProvider.notifier);

    // The app already scales the whole screen with the chosen preset; the
    // sample uses the same factor but animates it itself.
    final media = MediaQuery.of(context);
    final scale = option.factor ?? media.textScaler.scale(1);
    final duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.standard;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaQuery(
            data: media.copyWith(textScaler: TextScaler.noScaling),
            child: AnimatedDefaultTextStyle(
              duration: duration,
              curve: SacMotion.easeOut,
              style: TextStyle(
                fontSize: SacFontSize.titleMedium * scale,
                height: 1.35,
                color: c.text,
              ),
              child: Text('settings.appearance.sample_text'.tr()),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ExcludeSemantics(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedTextFont,
                  size: 14,
                  color: c.textTertiary,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _options.indexOf(option).toDouble(),
                  min: 0,
                  max: (_options.length - 1).toDouble(),
                  divisions: _options.length - 1,
                  activeColor: accent,
                  inactiveColor: c.border,
                  label: labelFor(option),
                  semanticFormatterCallback: (v) =>
                      labelFor(_options[v.round()]),
                  onChanged: (v) => notifier.setTextSize(_options[v.round()]),
                ),
              ),
              ExcludeSemantics(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedTextFont,
                  size: 20,
                  color: c.textTertiary,
                ),
              ),
            ],
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                labelFor(option),
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  color: c.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
