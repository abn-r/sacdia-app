import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';

import '../providers/members_providers.dart';

/// Barra de filtros para la lista de miembros
class MembersFilterBar extends ConsumerStatefulWidget {
  const MembersFilterBar({super.key});

  @override
  ConsumerState<MembersFilterBar> createState() => _MembersFilterBarState();
}

class _MembersFilterBarState extends ConsumerState<MembersFilterBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final filters = ref.watch(memberFiltersProvider);
    final availableClasses = ref.watch(availableClassesProvider);
    final availableRoles = ref.watch(availableRolesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search bar ────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              ref.read(memberFiltersProvider.notifier).state =
                  filters.copyWith(searchQuery: value);
            },
            style: TextStyle(fontSize: 14, color: c.text),
            decoration: InputDecoration(
              hintText: 'members.filter_bar.search_hint'.tr(),
              hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
              prefixIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                color: c.textTertiary,
                size: 20,
              ),
              suffixIcon: filters.searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        ref.read(memberFiltersProvider.notifier).state =
                            filters.copyWith(searchQuery: '');
                      },
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: c.textTertiary,
                        size: 18,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 14,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ── Chip filters ──────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Clase filter
              if (availableClasses.isNotEmpty)
                _FilterChip(
                  label: filters.classFilter ?? 'members.filter_bar.class_filter'.tr(),
                  isActive: filters.classFilter != null,
                  onTap: () => _showClassPicker(
                    context,
                    availableClasses,
                    filters.classFilter,
                  ),
                  onClear: filters.classFilter != null
                      ? () {
                          ref.read(memberFiltersProvider.notifier).state =
                              filters.copyWith(clearClass: true);
                        }
                      : null,
                ),

              const SizedBox(width: 8),

              // Rol filter
              if (availableRoles.isNotEmpty)
                _FilterChip(
                  label: filters.roleFilter != null
                      ? RoleUtils.translate(filters.roleFilter)
                      : 'members.filter_bar.role_filter'.tr(),
                  isActive: filters.roleFilter != null,
                  onTap: () => _showRolePicker(
                    context,
                    availableRoles,
                    filters.roleFilter,
                  ),
                  onClear: filters.roleFilter != null
                      ? () {
                          ref.read(memberFiltersProvider.notifier).state =
                              filters.copyWith(clearRole: true);
                        }
                      : null,
                ),

              const SizedBox(width: 8),

              // Inscripción filter
              _FilterChip(
                label: filters.enrolledFilter == null
                    ? 'members.filter_bar.status_filter'.tr()
                    : filters.enrolledFilter!
                        ? 'members.common.enrolled'.tr()
                        : 'members.common.not_enrolled'.tr(),
                isActive: filters.enrolledFilter != null,
                onTap: () => _showEnrollmentPicker(
                  context,
                  filters.enrolledFilter,
                ),
                onClear: filters.enrolledFilter != null
                    ? () {
                        ref.read(memberFiltersProvider.notifier).state =
                            filters.copyWith(clearEnrolled: true);
                      }
                    : null,
              ),

              // Clear all button
              if (filters.hasActiveFilters) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    ref.read(memberFiltersProvider.notifier).state =
                        const MemberFilters();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedFilterRemove,
                          color: AppColors.error,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'common.clear'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showClassPicker(
    BuildContext context,
    List<String> classes,
    String? current,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PickerSheet(
        title: 'members.filter_bar.class_picker_title'.tr(),
        options: classes,
        selected: current,
      ),
    );
    if (selected != null && mounted) {
      ref.read(memberFiltersProvider.notifier).state =
          ref.read(memberFiltersProvider).copyWith(classFilter: selected);
    }
  }

  Future<void> _showRolePicker(
    BuildContext context,
    List<String> roles,
    String? current,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PickerSheet(
        title: 'members.filter_bar.role_picker_title'.tr(),
        options: roles,
        selected: current,
        labelBuilder: RoleUtils.translate,
      ),
    );
    if (selected != null && mounted) {
      ref.read(memberFiltersProvider.notifier).state =
          ref.read(memberFiltersProvider).copyWith(roleFilter: selected);
    }
  }

  Future<void> _showEnrollmentPicker(
    BuildContext context,
    bool? current,
  ) async {
    final selected = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EnrollmentPickerSheet(current: current),
    );
    if (mounted && selected != null) {
      ref.read(memberFiltersProvider.notifier).state =
          ref.read(memberFiltersProvider).copyWith(enrolledFilter: selected);
    }
  }
}

/// Chip de filtro reutilizable
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final bgColor = isActive
        ? AppColors.primary.withValues(alpha: 0.12)
        : c.surfaceVariant;
    final fgColor = isActive ? AppColors.primary : c.textSecondary;
    final borderColor = isActive ? AppColors.primaryLight : c.border;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: fgColor,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  color: fgColor,
                  size: 12,
                ),
              ),
            ] else ...[
              const SizedBox(width: 4),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                color: fgColor,
                size: 12,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sheet genérico para selección de opciones
class _PickerSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final String Function(String)? labelBuilder;

  const _PickerSheet({
    required this.title,
    required this.options,
    this.selected,
    this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                // shrinkWrap removed: Flexible already provides a bounded
                // height constraint, so ListView can scroll normally.
                children: [
                  ...options.map((option) {
                    final label = labelBuilder?.call(option) ?? option;
                    final isSelected = option == selected;
                    return ListTile(
                      title: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? AppColors.primary : c.text,
                        ),
                      ),
                      trailing: isSelected
                          ? const HugeIcon(
                              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                              color: AppColors.primary,
                              size: 20,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, option),
                    );
                  }),
                  SizedBox(height: 16 + bottomInset),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet para filtrar por estado de inscripción
class _EnrollmentPickerSheet extends StatelessWidget {
  final bool? current;

  const _EnrollmentPickerSheet({this.current});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'members.filter_bar.enrollment_picker_title'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text(
              'members.common.enrolled'.tr(),
              style: TextStyle(
                fontSize: 15,
                color: current == true ? AppColors.primary : c.text,
                fontWeight:
                    current == true ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            trailing: current == true
                ? const HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                    color: AppColors.primary,
                    size: 20,
                  )
                : null,
            onTap: () => Navigator.pop(context, true),
          ),
          ListTile(
            title: Text(
              'members.common.not_enrolled'.tr(),
              style: TextStyle(
                fontSize: 15,
                color: current == false ? AppColors.primary : c.text,
                fontWeight:
                    current == false ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            trailing: current == false
                ? const HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                    color: AppColors.primary,
                    size: 20,
                  )
                : null,
            onTap: () => Navigator.pop(context, false),
          ),
          SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
