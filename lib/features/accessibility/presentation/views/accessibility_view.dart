import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../profile/presentation/widgets/setting_tile.dart';
import '../../domain/entities/accessibility_settings.dart';
import '../providers/accessibility_provider.dart';

class AccessibilityView extends ConsumerWidget {
  const AccessibilityView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.surfaceVariant,
      appBar: AppBar(
        title: Text('accessibility.title'.tr()),
        backgroundColor: c.surfaceVariant,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _GroupContainer(
            children: [
              SettingTile(
                icon: HugeIcons.strokeRoundedTextFont,
                title: 'accessibility.text_size_label'.tr(),
                subtitle: _labelForTextSize(settings.textSize),
                iconColor: AppColors.primary,
                onTap: () => _showTextSizePicker(context, ref),
              ),
              _divider(context),
              _SwitchTile(
                icon: HugeIcons.strokeRoundedMoonEclipse,
                title: 'accessibility.high_contrast_tile'.tr(),
                iconColor: AppColors.primary,
                value: settings.highContrast,
                onChanged: notifier.setHighContrast,
              ),
              _divider(context),
              _SwitchTile(
                icon: HugeIcons.strokeRoundedPause,
                title: 'accessibility.reduce_motion_tile'.tr(),
                iconColor: AppColors.primary,
                value: settings.reduceMotion,
                onChanged: notifier.setReduceMotion,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Live preview — aplica la configuración actual dentro de un
          // MediaQuery local para que el usuario vea el efecto sin salir
          // de la pantalla. El override global a nivel de app sigue vigente;
          // este MediaQuery anidado solamente refuerza que el preview
          // refleje el estado incluso antes de que la rebuild raíz propague.
          _PreviewCard(settings: settings),
        ],
      ),
    );
  }

  static String _labelForTextSize(TextSizeOption option) {
    switch (option) {
      case TextSizeOption.system:
        return 'accessibility.text_size_system'.tr();
      case TextSizeOption.normal:
        return 'accessibility.text_size_normal'.tr();
      case TextSizeOption.large:
        return 'accessibility.text_size_large'.tr();
      case TextSizeOption.extraLarge:
        return 'accessibility.text_size_extra_large'.tr();
    }
  }

  Future<void> _showTextSizePicker(BuildContext context, WidgetRef ref) async {
    final current = ref.read(accessibilityProvider).textSize;
    final picked = await showModalBottomSheet<TextSizeOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextSizePickerSheet(current: current),
    );
    if (picked != null) {
      await ref.read(accessibilityProvider.notifier).setTextSize(picked);
    }
  }

  Widget _divider(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        indent: 60,
        color: context.sac.borderLight,
      );
}

class _PreviewCard extends StatelessWidget {
  final AccessibilitySettings settings;
  const _PreviewCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final base = MediaQuery.of(context);
    final merged = mergedAccessibilityMediaQueryData(base, settings);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'accessibility.preview_title'.tr(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textTertiary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          MediaQuery(
            data: merged,
            child: Text(
              'accessibility.preview_text'.tr(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Text size picker ─────────────────────────────────────────────────────────

class _TextSizePickerSheet extends StatelessWidget {
  final TextSizeOption current;
  const _TextSizePickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final options = [
      (TextSizeOption.system, 'accessibility.text_size_system'.tr()),
      (TextSizeOption.normal, 'accessibility.text_size_normal'.tr()),
      (TextSizeOption.large, 'accessibility.text_size_large'.tr()),
      (TextSizeOption.extraLarge, 'accessibility.text_size_extra_large'.tr()),
    ];

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
            'accessibility.text_size_label'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ...options.map((entry) {
            final (option, label) = entry;
            final selected = option == current;
            return ListTile(
              title: Text(label),
              trailing: selected
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.of(context).pop(option),
            );
          }),
        ],
      ),
    );
  }
}

// ── Reusable bits (local copies scoped to accessibility view) ───────────────

class _GroupContainer extends StatelessWidget {
  final List<Widget> children;
  const _GroupContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.sac.border, width: 1),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final HugeIconData icon;
  final String title;
  final Color? iconColor;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    this.iconColor,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final effectiveIconColor = iconColor ?? c.textSecondary;
    final effectiveBg = iconColor != null
        ? iconColor!.withValues(alpha: 0.12)
        : c.surfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: effectiveBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: HugeIcon(
                icon: icon,
                color: effectiveIconColor,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.text,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
