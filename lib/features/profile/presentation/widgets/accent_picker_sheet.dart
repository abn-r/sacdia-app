import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/accent_provider.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

/// Selector de acento. El swatch muestra el color canónico, no el tono
/// aclarado del modo oscuro.
Future<void> showAccentPicker(BuildContext context, WidgetRef ref) {
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.sac.surface,
    builder: (sheetContext) {
      final selectedId = ref.read(accentNotifierProvider).id;
      return _AccentPickerSheet(
        selectedId: selectedId,
        onSelect: (accent) async {
          await ref.read(accentNotifierProvider.notifier).setAccent(accent);
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        },
      );
    },
  );
}

class _AccentPickerSheet extends StatelessWidget {
  const _AccentPickerSheet({
    required this.selectedId,
    required this.onSelect,
  });

  final String selectedId;
  final ValueChanged<SacAccent> onSelect;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.86;
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(title: 'profile.settings.accent_sheet_title'.tr()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _AccentGroup(
                  title: 'profile.settings.accent_group_brand'.tr(),
                  accents: _where(AccentFamily.brand),
                  selectedId: selectedId,
                  onSelect: onSelect,
                ),
                _AccentGroup(
                  title: 'profile.settings.accent_group_clubs'.tr(),
                  accents: _where(AccentFamily.club),
                  selectedId: selectedId,
                  onSelect: onSelect,
                ),
                _AccentGroup(
                  title: 'profile.settings.accent_classes_aventureros'.tr(),
                  accents: _classes(AccentClub.aventureros),
                  selectedId: selectedId,
                  onSelect: onSelect,
                ),
                _AccentGroup(
                  title: 'profile.settings.accent_classes_conquistadores'.tr(),
                  accents: _classes(AccentClub.conquistadores),
                  selectedId: selectedId,
                  onSelect: onSelect,
                ),
                _AccentGroup(
                  title: 'profile.settings.accent_classes_guias'.tr(),
                  accents: _classes(AccentClub.guiasMayores),
                  selectedId: selectedId,
                  onSelect: onSelect,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<SacAccent> _where(AccentFamily family) {
    return [
      for (final accent in SacAccent.catalog)
        if (accent.family == family) accent,
    ];
  }

  List<SacAccent> _classes(AccentClub club) {
    return [
      for (final accent in SacAccent.catalog)
        if (accent.family == AccentFamily.classLevel && accent.club == club)
          accent,
    ];
  }
}

class _AccentGroup extends StatelessWidget {
  const _AccentGroup({
    required this.title,
    required this.accents,
    required this.selectedId,
    required this.onSelect,
  });

  final String title;
  final List<SacAccent> accents;
  final String selectedId;
  final ValueChanged<SacAccent> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: c.textTertiary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final accent in accents)
          _AccentRow(
            accent: accent,
            selected: accent.id == selectedId,
            onTap: () => onSelect(accent),
          ),
      ],
    );
  }
}

class _AccentRow extends StatelessWidget {
  const _AccentRow({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final SacAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacInkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accent.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.border),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  accent.labelKey.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: c.text,
                  ),
                ),
              ),
              if (selected)
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTick02,
                  size: 18,
                  color: c.text,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
