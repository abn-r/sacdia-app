import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/accent_provider.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// The accent catalog as circular swatches, grouped (brand, clubs and the
/// classes of each club). Tapping one applies it right away.
class AppearanceAccentSwatches extends ConsumerWidget {
  const AppearanceAccentSwatches({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final selectedId = ref.watch(accentNotifierProvider).id;
    final notifier = ref.read(accentNotifierProvider.notifier);

    final groups = <(String, List<SacAccent>)>[
      (
        'profile.settings.accent_group_brand',
        _where((a) => a.family == AccentFamily.brand),
      ),
      (
        'profile.settings.accent_group_clubs',
        _where((a) => a.family == AccentFamily.club),
      ),
      (
        'profile.settings.accent_classes_aventureros',
        _classes(AccentClub.aventureros),
      ),
      (
        'profile.settings.accent_classes_conquistadores',
        _classes(AccentClub.conquistadores),
      ),
      (
        'profile.settings.accent_classes_guias',
        _classes(AccentClub.guiasMayores),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (labelKey, accents) in groups) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                labelKey.tr(),
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                children: [
                  for (final accent in accents)
                    _AccentSwatch(
                      key: ValueKey('accent-${accent.id}'),
                      accent: accent,
                      selected: accent.id == selectedId,
                      onTap: () => notifier.setAccent(accent),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static List<SacAccent> _where(bool Function(SacAccent) test) => [
        for (final a in SacAccent.catalog)
          if (test(a)) a
      ];

  static List<SacAccent> _classes(AccentClub club) => _where(
        (a) => a.family == AccentFamily.classLevel && a.club == club,
      );
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    super.key,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final SacAccent accent;
  final bool selected;
  final VoidCallback onTap;

  static const double _slot = 48;
  static const double _ringWidth = 2;
  static const double _ringGap = 3;
  static const double _pressScale = 0.92;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.press;

    return Semantics(
      button: true,
      selected: selected,
      label: accent.labelKey.tr(),
      excludeSemantics: true,
      onTap: onTap,
      child: SacPressable(
        onTap: onTap,
        pressedScale: _pressScale,
        child: SizedBox(
          width: _slot,
          height: _slot,
          child: Center(
            child: AnimatedContainer(
              duration: duration,
              curve: SacMotion.easeOut,
              padding: const EdgeInsets.all(_ringGap),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? c.text : Colors.transparent,
                  width: _ringWidth,
                ),
              ),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.border),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
