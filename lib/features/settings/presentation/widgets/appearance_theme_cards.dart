import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/theme_provider.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// Section eyebrow of the appearance screen: uppercase [title] and, at the
/// right, an optional [trailing] value (the chosen accent name).
class AppearanceEyebrow extends StatelessWidget {
  const AppearanceEyebrow({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: SacFontSize.labelSmall,
                  fontWeight: FontWeight.w600,
                  color: c.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Three selectable theme cards (system, light, dark) with a small drawn
/// preview. Choosing one applies it right away.
class AppearanceThemeCards extends ConsumerWidget {
  const AppearanceThemeCards({super.key});

  static const _options = <(ThemeMode, String, _PreviewKind)>[
    (ThemeMode.system, 'profile.settings.theme_system', _PreviewKind.split),
    (ThemeMode.light, 'profile.settings.theme_light', _PreviewKind.light),
    (ThemeMode.dark, 'profile.settings.theme_dark', _PreviewKind.dark),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeNotifierProvider);
    final notifier = ref.read(themeNotifierProvider.notifier);

    void select(ThemeMode next) {
      switch (next) {
        case ThemeMode.light:
          notifier.setLightTheme();
        case ThemeMode.dark:
          notifier.setDarkTheme();
        case ThemeMode.system:
          notifier.setSystemTheme();
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _options.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _ThemeOptionCard(
              key: ValueKey('theme-card-${_options[i].$1.name}'),
              label: _options[i].$2.tr(),
              kind: _options[i].$3,
              selected: mode == _options[i].$1,
              onTap: () => select(_options[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

enum _PreviewKind { light, dark, split }

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    super.key,
    required this.label,
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final _PreviewKind kind;
  final bool selected;
  final VoidCallback onTap;

  static const double _borderWidth = 2;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final reduceMotion = SacMotion.reduceMotionOf(context);
    final duration = reduceMotion ? Duration.zero : SacMotion.standard;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: SacPressable(
        onTap: onTap,
        pressedScale: SacMotion.panelPressScale,
        child: AnimatedContainer(
          duration: duration,
          curve: SacMotion.easeOut,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: selected ? accent.color : c.border,
              width: _borderWidth,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: _ThemePreview(kind: kind)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: c.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedOpacity(
                    duration: duration,
                    opacity: selected ? 1 : 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: accent.color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedTick02,
                          size: 10,
                          color: accent.onColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mini screen drawn with the real light and dark palettes, so it looks the
/// same whichever theme is active.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.kind});

  final _PreviewKind kind;

  static const double _height = 64;

  @override
  Widget build(BuildContext context) {
    const light = SacColors(Brightness.light);
    const dark = SacColors(Brightness.dark);
    final border = context.sac.border;

    return Container(
      height: _height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: border),
      ),
      child: switch (kind) {
        _PreviewKind.light => const _PreviewSurface(colors: light),
        _PreviewKind.dark => const _PreviewSurface(colors: dark),
        _PreviewKind.split => const Row(
            children: [
              Expanded(child: _PreviewSurface(colors: light)),
              Expanded(child: _PreviewSurface(colors: dark)),
            ],
          ),
      },
    );
  }
}

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({required this.colors});

  final SacColors colors;

  static const double _barHeight = 6;

  Widget _bar(Color color, double widthFactor) => FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: _barHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppTheme.radiusHairline),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final muted = colors.textTertiary.withValues(alpha: 0.4);
    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _bar(SacAccent.of(context).color, 0.9),
              _bar(muted, 0.6),
              _bar(muted, 0.75),
            ],
          ),
        ),
      ),
    );
  }
}
