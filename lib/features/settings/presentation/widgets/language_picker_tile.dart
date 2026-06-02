import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../profile/presentation/widgets/setting_tile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';

class LanguagePickerTile extends StatelessWidget {
  const LanguagePickerTile({super.key});

  static const _locales = <_LocaleOption>[
    _LocaleOption(locale: Locale('es'), flag: '🇲🇽', label: 'Español'),
    _LocaleOption(
      locale: Locale('pt', 'BR'),
      flag: '🇧🇷',
      label: 'Português (Brasil)',
    ),
    _LocaleOption(locale: Locale('en'), flag: '🇺🇸', label: 'English'),
    _LocaleOption(locale: Locale('fr'), flag: '🇫🇷', label: 'Français'),
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
            _FlagEmoji(flag: current.flag, compact: true),
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
  final String flag;
  final String label;
  const _LocaleOption({
    required this.locale,
    required this.flag,
    required this.label,
  });
}

class _FlagEmoji extends StatelessWidget {
  const _FlagEmoji({required this.flag, this.compact = false});

  static const _emojiFontFallback = <String>[
    'Apple Color Emoji',
    'Noto Color Emoji',
    'Segoe UI Emoji',
  ];

  final String flag;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text(
      flag,
      style: TextStyle(
        fontSize: compact ? 17 : 24,
        fontFamilyFallback: _emojiFontFallback,
      ),
    );
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
              leading: _FlagEmoji(flag: o.flag),
              title: Text(
                o.label,
                style: TextStyle(color: c.text),
              ),
              trailing: isCurrent
                  ? const Icon(Icons.check, color: AppColors.secondary)
                  : null,
              onTap: () => Navigator.of(context).pop(o.locale),
            );
          }),
        ],
      ),
    );
  }
}
