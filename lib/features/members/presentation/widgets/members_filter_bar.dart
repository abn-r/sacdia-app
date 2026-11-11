import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/fixed_input_icon_slot.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

import '../providers/members_providers.dart';
import 'members_filter_sheet.dart';

/// Barra de filtros para la lista de miembros: búsqueda y botón de filtros.
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

  Future<void> _openFilterSheet(
    List<String> classes,
    List<String> roles,
  ) async {
    final result = await showSacSheet<MemberFilters>(
      context: context,
      // Sobre la bottom nav del shell, no detrás.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MembersFilterSheet(
        initial: ref.read(memberFiltersProvider),
        classes: classes,
        roles: roles,
      ),
    );
    if (result == null || !mounted) return;
    final current = ref.read(memberFiltersProvider);
    ref.read(memberFiltersProvider.notifier).state = MemberFilters(
      searchQuery: current.searchQuery,
      classFilter: result.classFilter,
      roleFilter: result.roleFilter,
      enrolledFilter: result.enrolledFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final filters = ref.watch(memberFiltersProvider);
    final availableClasses = sortClassFilterOptions(
      ref.watch(availableClassesProvider),
      ref.watch(membersNotifierProvider).value?.members ?? const [],
      noClassLabel: 'members.errors.no_class'.tr(),
      guideMajorsLabel: 'members.guide_majors_group'.tr(),
    );
    final availableRoles = ref.watch(availableRolesProvider);
    final activeCount = [
      filters.classFilter,
      filters.roleFilter,
      filters.enrolledFilter,
    ].where((value) => value != null).length;

    // Un reinicio externo (p. ej. «Limpiar filtros») vacía también el campo.
    ref.listen<MemberFilters>(memberFiltersProvider, (_, next) {
      if (next.searchQuery.isEmpty && _searchController.text.isNotEmpty) {
        _searchController.clear();
      }
    });

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: Border.all(color: c.border),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                ref.read(memberFiltersProvider.notifier).state =
                    ref.read(memberFiltersProvider).copyWith(
                          searchQuery: value,
                        );
              },
              style: TextStyle(fontSize: SacFontSize.titleSmall, color: c.text),
              decoration: InputDecoration(
                hintText: 'members.filter_bar.search_hint'.tr(),
                hintStyle: TextStyle(
                    color: c.textTertiary, fontSize: SacFontSize.titleSmall),
                prefixIconConstraints: FixedInputIconSlot.constraints,
                prefixIcon: FixedInputIconSlot(
                  icon: HugeIcons.strokeRoundedSearch01,
                  color: c.textTertiary,
                  iconSize: 20,
                ),
                suffixIconConstraints: FixedInputIconSlot.constraints,
                suffixIcon: filters.searchQuery.isNotEmpty
                    ? Semantics(
                        button: true,
                        label: 'common.clear'.tr(),
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _searchController.clear();
                            ref.read(memberFiltersProvider.notifier).state = ref
                                .read(memberFiltersProvider)
                                .copyWith(searchQuery: '');
                          },
                          child: FixedInputIconSlot(
                            icon: HugeIcons.strokeRoundedCancel01,
                            color: c.textTertiary,
                            iconSize: 18,
                          ),
                        ),
                      )
                    : null,
                // The container draws the border; drop the theme's own.
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _FilterButton(
          activeCount: activeCount,
          onTap: () => _openFilterSheet(availableClasses, availableRoles),
        ),
      ],
    );
  }
}

/// Botón cuadrado que abre la hoja de filtros. Con filtros activos se tiñe
/// del acento y muestra cuántos hay.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onTap});

  static const double size = 48;

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final isActive = activeCount > 0;

    return SacPressable(
      onTap: onTap,
      semanticLabel: isActive
          ? '${'members.filter_bar.filters_button'.tr()} ($activeCount)'
          : 'members.filter_bar.filters_button'.tr(),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  border: Border.all(color: c.border),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedFilterHorizontal,
                    color: isActive ? accent.color : c.text,
                    size: 20,
                  ),
                ),
              ),
            ),
            if (isActive)
              Positioned(
                top: -4,
                right: -4,
                child: ExcludeSemantics(
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.color,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      '$activeCount',
                      style: TextStyle(
                        fontSize: SacFontSize.labelSmall,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: accent.onColor,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
