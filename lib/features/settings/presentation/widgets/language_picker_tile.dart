import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../profile/presentation/widgets/setting_tile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';

class LanguagePickerTile extends StatelessWidget {
  const LanguagePickerTile({super.key});

  static const _locales = <_LocaleOption>[
    _LocaleOption(locale: Locale('es'), code: 'ES', label: 'Español'),
    _LocaleOption(
      locale: Locale('pt', 'BR'),
      code: 'BR',
      label: 'Português (Brasil)',
    ),
    _LocaleOption(locale: Locale('en'), code: 'EN', label: 'English'),
    _LocaleOption(locale: Locale('fr'), code: 'FR', label: 'Français'),
  ];

  static _LocaleOption _currentOption(Locale current) {
    return _locales.firstWhere(
      (o) =>
          o.locale.languageCode == current.languageCode &&
          (o.locale.countryCode ?? '') == (current.countryCode ?? ''),
      orElse: () => _locales.first,
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final current = context.locale;
    final picked = await showModalBottomSheet<Locale>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _LocalePickerSheet(current: current),
    );
    if (picked != null && context.mounted) {
      await context.setLocale(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentOption(context.locale);
    return SettingTile(
      icon: HugeIcons.strokeRoundedGlobe02,
      title: 'settings.language_picker_title'.tr(),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.42,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _LanguageFlagBadge(option: current, compact: true),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                current.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.sac.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
      iconColor: AppColors.primary,
      onTap: () => _showPicker(context),
    );
  }
}

class _LocaleOption {
  final Locale locale;
  final String code;
  final String label;
  const _LocaleOption({
    required this.locale,
    required this.code,
    required this.label,
  });
}

class _LanguageFlagBadge extends StatelessWidget {
  const _LanguageFlagBadge({
    required this.option,
    this.compact = false,
  });

  final _LocaleOption option;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(option.locale);
    final width = compact ? 34.0 : 42.0;
    final height = compact ? 22.0 : 28.0;

    return Semantics(
      label: option.label,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.sac.surface,
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          border: Border.all(color: context.sac.border),
          boxShadow: [
            BoxShadow(
              color: context.sac.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Row(
              children: colors
                  .map(
                    (color) => Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: color),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            Center(
              child: Text(
                option.code,
                style: TextStyle(
                  color: _textColorFor(option.locale),
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<Color> _colorsFor(Locale locale) {
    final language = locale.languageCode;
    final country = locale.countryCode;

    if (language == 'es') {
      return const [Color(0xFFAA151B), Color(0xFFF1BF00), Color(0xFFAA151B)];
    }
    if (language == 'pt' && country == 'BR') {
      return const [Color(0xFF009B3A), Color(0xFFFFDF00), Color(0xFF002776)];
    }
    if (language == 'fr') {
      return const [Color(0xFF0055A4), Colors.white, Color(0xFFEF4135)];
    }
    return const [Color(0xFF1F3F8B), Colors.white, Color(0xFFB22234)];
  }

  static Color _textColorFor(Locale locale) {
    if (locale.languageCode == 'fr') return const Color(0xFF111827);
    return Colors.white;
  }
}

class _LocalePickerSheet extends StatelessWidget {
  const _LocalePickerSheet({required this.current});
  final Locale current;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'settings.language_picker_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
          ),
          const SizedBox(height: 12),
          ...LanguagePickerTile._locales.map((o) {
            final isCurrent = o.locale.languageCode == current.languageCode &&
                (o.locale.countryCode ?? '') == (current.countryCode ?? '');
            return ListTile(
              leading: _LanguageFlagBadge(option: o),
              title: Text(
                o.label,
                style: TextStyle(color: c.text),
              ),
              trailing: isCurrent
                  ? const HugeIcon(
                      icon: HugeIcons.strokeRoundedTick02,
                      color: AppColors.secondary)
                  : null,
              onTap: () => Navigator.of(context).pop(o.locale),
            );
          }),
        ],
      ),
    );
  }
}
