import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../profile/presentation/widgets/setting_tile.dart';
import '../../../../core/theme/app_colors.dart';

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
      trailing: Text(
        '${current.flag}  ${current.label}',
        style: Theme.of(context).textTheme.bodySmall,
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

class _LocalePickerSheet extends StatelessWidget {
  const _LocalePickerSheet({required this.current});
  final Locale current;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                color: Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'settings.language_picker_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          ...LanguagePickerTile._locales.map((o) {
            final isCurrent = o.locale.languageCode == current.languageCode &&
                (o.locale.countryCode ?? '') == (current.countryCode ?? '');
            return ListTile(
              leading: Text(o.flag, style: const TextStyle(fontSize: 24)),
              title: Text(o.label),
              trailing: isCurrent
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => Navigator.of(context).pop(o.locale),
            );
          }),
        ],
      ),
    );
  }
}
