import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/club_type.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/fixed_input_icon_slot.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

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
    final availableClasses = sortClassFilterOptions(
      ref.watch(availableClassesProvider),
      ref.watch(membersNotifierProvider).valueOrNull?.members ?? const [],
      noClassLabel: 'members.errors.no_class'.tr(),
      guideMajorsLabel: 'members.guide_majors_group'.tr(),
    );
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
              prefixIconConstraints: FixedInputIconSlot.constraints,
              prefixIcon: FixedInputIconSlot(
                icon: HugeIcons.strokeRoundedSearch01,
                color: c.textTertiary,
                iconSize: 20,
              ),
              suffixIconConstraints: FixedInputIconSlot.constraints,
              suffixIcon: filters.searchQuery.isNotEmpty
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _searchController.clear();
                        ref.read(memberFiltersProvider.notifier).state =
                            filters.copyWith(searchQuery: '');
                      },
                      child: FixedInputIconSlot(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: c.textTertiary,
                        iconSize: 18,
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
                  label: filters.classFilter ??
                      'members.filter_bar.class_filter'.tr(),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    final selected = await showSacSheet<String>(
      context: context,
      // Sobre la bottom nav del shell, no detrás.
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // El arrastre lo controla la hoja: así la lista la hace crecer.
      enableDrag: false,
      builder: (_) => _PickerSheet(
        title: 'members.filter_bar.class_picker_title'.tr(),
        options: classes,
        selected: current,
        showClassLogos: true,
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
    final selected = await showSacSheet<String>(
      context: context,
      // Sobre la bottom nav del shell, no detrás.
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
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
    final selected = await showSacSheet<bool>(
      context: context,
      // Sobre la bottom nav del shell, no detrás.
      useRootNavigator: true,
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
        ? SacAccent.of(context).color.withValues(alpha: 0.12)
        : c.surfaceVariant;
    final fgColor = isActive ? SacAccent.of(context).color : c.textSecondary;
    final borderColor = isActive ? SacAccent.of(context).light : c.border;

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

/// Sheet genérico para selección de opciones.
///
/// Abre a la mitad de la pantalla y crece al desplazar la lista, hasta dejar
/// un margen arriba. El mismo tamaño aplica a clase y a cargo.
class _PickerSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final String Function(String)? labelBuilder;
  final bool showClassLogos;

  static const double initialChildSize = 0.5;
  static const double minChildSize = 0.45;
  static const double maxChildSize = 0.92;

  const _PickerSheet({
    required this.title,
    required this.options,
    this.selected,
    this.labelBuilder,
    this.showClassLogos = false,
  });

  /// Logo de clase. Sin mapeo, la fila queda solo con texto.
  /// «Guías Mayores» usa el logo del club; «Sin clase» no tiene logo.
  String? _logoAsset(String option) {
    if (!showClassLogos) return null;
    final mapped = AppColors.classLogoAsset(option);
    if (mapped != null) return mapped;
    if (option == 'members.guide_majors_group'.tr() ||
        option == 'Guías Mayores') {
      return ClubType.guiasMayores.logoAsset;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      builder: (context, scrollController) {
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _FilterPickerHeaderDelegate(
                  title: title,
                  background: c.surfaceVariant,
                  handleColor: c.border,
                  titleColor: c.text,
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final option = options[index];
                    final label = labelBuilder?.call(option) ?? option;
                    final isSelected = option == selected;
                    final logo = _logoAsset(option);
                    return SacPressable(
                      listenOnly: true,
                      child: ListTile(
                        enableFeedback: false,
                        minLeadingWidth: 24,
                        horizontalTitleGap: 8,
                        leading: logo == null
                            ? null
                            : Image.asset(
                                logo,
                                key: ValueKey(
                                    'member-filter-class-logo-$option'),
                                width: 24,
                                height: 24,
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                              ),
                        title: Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? SacAccent.of(context).color
                                : c.text,
                          ),
                        ),
                        trailing: isSelected
                            ? HugeIcon(
                                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                                color: SacAccent.of(context).color,
                                size: 20,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, option),
                      ),
                    );
                  },
                  childCount: options.length,
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 16 + bottomInset)),
            ],
          ),
        );
      },
    );
  }
}

class _FilterPickerHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterPickerHeaderDelegate({
    required this.title,
    required this.background,
    required this.handleColor,
    required this.titleColor,
  });

  final String title;
  final Color background;
  final Color handleColor;
  final Color titleColor;

  static const double extent = 76;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: background,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: titleColor,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterPickerHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        background != oldDelegate.background ||
        handleColor != oldDelegate.handleColor ||
        titleColor != oldDelegate.titleColor;
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
          SacPressable(
            listenOnly: true,
            child: ListTile(
              enableFeedback: false,
              title: Text(
                'members.common.enrolled'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  color: current == true ? SacAccent.of(context).color : c.text,
                  fontWeight:
                      current == true ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              trailing: current == true
                  ? HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                      color: SacAccent.of(context).color,
                      size: 20,
                    )
                  : null,
              onTap: () => Navigator.pop(context, true),
            ),
          ),
          SacPressable(
            listenOnly: true,
            child: ListTile(
              enableFeedback: false,
              title: Text(
                'members.common.not_enrolled'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  color:
                      current == false ? SacAccent.of(context).color : c.text,
                  fontWeight:
                      current == false ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              trailing: current == false
                  ? HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                      color: SacAccent.of(context).color,
                      size: 20,
                    )
                  : null,
              onTap: () => Navigator.pop(context, false),
            ),
          ),
          SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
