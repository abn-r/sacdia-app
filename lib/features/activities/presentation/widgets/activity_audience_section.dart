import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';

import '../../../classes/domain/entities/progressive_class.dart';
import '../../../classes/presentation/providers/classes_providers.dart';
import '../../domain/entities/activity_club_section.dart';

final activityClassOptionsProvider = FutureProvider.autoDispose
    .family<List<ProgressiveClass>, String>((ref, key) async {
  if (key.isEmpty) return const [];
  final ids = key
      .split(',')
      .map(int.tryParse)
      .whereType<int>()
      .where((id) => id > 0)
      .toList();
  final lists = await Future.wait(
    ids.map((id) => ref.watch(classesByClubTypeProvider(id).future)),
  );
  final byId = <int, ProgressiveClass>{};
  for (final item in lists.expand((list) => list)) {
    byId[item.id] = item;
  }
  final classes = byId.values.toList()
    ..sort((a, b) {
      final byType = a.clubTypeId.compareTo(b.clubTypeId);
      if (byType != 0) return byType;
      return a.name.compareTo(b.name);
    });
  return classes;
});

class ActivityAudienceSection extends ConsumerStatefulWidget {
  final List<ActivityClubSection> sections;
  final int ownSectionId;
  final bool isJoint;
  final Set<int> selectedSectionIds;
  final String audience;
  final Set<int> selectedClassIds;
  final ValueChanged<String> onAudience;
  final ValueChanged<Set<int>> onClasses;

  const ActivityAudienceSection({
    super.key,
    required this.sections,
    required this.ownSectionId,
    required this.isJoint,
    required this.selectedSectionIds,
    required this.audience,
    required this.selectedClassIds,
    required this.onAudience,
    required this.onClasses,
  });

  @override
  ConsumerState<ActivityAudienceSection> createState() =>
      _ActivityAudienceSectionState();
}

class _ActivityAudienceSectionState
    extends ConsumerState<ActivityAudienceSection> {
  String? _syncedKey;

  List<int> get _sectionIds {
    if (widget.isJoint && widget.selectedSectionIds.isNotEmpty) {
      return widget.selectedSectionIds.toList()..sort();
    }
    return [widget.ownSectionId];
  }

  String get _clubTypeKey {
    final types = widget.sections
        .where((section) => _sectionIds.contains(section.clubSectionId))
        .map((section) => section.clubTypeId)
        .where((id) => id > 0)
        .toSet()
        .toList()
      ..sort();
    return types.join(',');
  }

  @override
  void didUpdateWidget(ActivityAudienceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _clubTypeKey;
    final audienceOpened =
        oldWidget.audience != 'classes' && widget.audience == 'classes';
    final sectionsChanged = oldWidget.isJoint != widget.isJoint ||
        oldWidget.selectedSectionIds.length !=
            widget.selectedSectionIds.length ||
        !oldWidget.selectedSectionIds.containsAll(widget.selectedSectionIds);
    if (audienceOpened || sectionsChanged) {
      _syncedKey = null;
      if (nextKey.isEmpty) return;
    }
  }

  void _selectAll(List<ProgressiveClass> classes, String key) {
    if (_syncedKey == key) return;
    _syncedKey = key;
    widget.onClasses(classes.map((item) => item.id).toSet());
  }

  @override
  Widget build(BuildContext context) {
    final key = _clubTypeKey;
    final classesAsync = ref.watch(activityClassOptionsProvider(key));
    if (widget.audience == 'classes' &&
        classesAsync.hasValue &&
        _syncedKey != key) {
      final classes = classesAsync.requireValue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _syncedKey == key) return;
        _selectAll(classes, key);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'activities.form.audience_label'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ModeChip(
              label: 'activities.form.audience_all'.tr(),
              selected: widget.audience == 'all',
              onTap: () => widget.onAudience('all'),
            ),
            _ModeChip(
              label: 'activities.form.audience_board'.tr(),
              selected: widget.audience == 'board',
              onTap: () => widget.onAudience('board'),
            ),
            _ModeChip(
              label: 'activities.form.audience_classes'.tr(),
              selected: widget.audience == 'classes',
              onTap: () => widget.onAudience('classes'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.audience == 'board'
              ? 'activities.form.audience_board_help'.tr()
              : widget.audience == 'classes'
                  ? 'activities.form.audience_classes_help'.tr()
                  : 'activities.form.audience_all_help'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
        ),
        if (widget.audience == 'classes') ...[
          const SizedBox(height: 12),
          classesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Text('activities.form.audience_classes_error'.tr()),
            data: (classes) {
              if (classes.isEmpty) {
                return Text('activities.form.audience_classes_empty'.tr());
              }
              return Wrap(
                spacing: 8,
                runSpacing: 12,
                children: [
                  for (final item in classes)
                    _ClassLogoTile(
                      name: item.name,
                      asset: _logoAsset(item),
                      selected: widget.selectedClassIds.contains(item.id),
                      onTap: () {
                        final next = {...widget.selectedClassIds};
                        if (!next.add(item.id)) next.remove(item.id);
                        _syncedKey = key;
                        widget.onClasses(next);
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

String? _logoAsset(ProgressiveClass item) {
  final code = item.assetCode?.trim().toUpperCase();
  if (code != null && RegExp(r'^(AV|CQ|GM)-\d{2}$').hasMatch(code)) {
    return 'assets/img/logos-clases/$code.png';
  }
  return AppColors.classLogoAsset(item.name);
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SacAccent.of(context).color : SacAccent.of(context).light,
      borderRadius: BorderRadius.circular(20),
      child: SacInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : SacAccent.of(context).dark,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassLogoTile extends StatelessWidget {
  final String name;
  final String? asset;
  final bool selected;
  final VoidCallback onTap;

  const _ClassLogoTile({
    required this.name,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SacInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? SacAccent.of(context).color : Colors.transparent,
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: ColoredBox(
                  color: selected
                      ? SacAccent.of(context).light
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: asset == null
                      ? _initial(context)
                      : Image.asset(
                          asset!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _initial(context),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? SacAccent.of(context).dark : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initial(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: SacAccent.of(context).dark,
        ),
      ),
    );
  }
}
