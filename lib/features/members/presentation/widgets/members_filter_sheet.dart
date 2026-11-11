import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/club_type.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';

import '../providers/members_providers.dart';

/// Logo de clase. Sin mapeo, el chip queda solo con texto.
/// «Guías Mayores» usa el logo del club; «Sin clase» no tiene logo.
String? memberFilterClassLogo(String option) {
  final mapped = AppColors.classLogoAsset(option);
  if (mapped != null) return mapped;
  if (option == 'members.guide_majors_group'.tr() ||
      option == 'Guías Mayores') {
    return ClubType.guiasMayores.logoAsset;
  }
  return null;
}

/// Hoja única de filtros (clase, cargo, inscripción).
///
/// Trabaja sobre un borrador: nada se aplica hasta pulsar «Ver N miembros»,
/// que cierra la hoja devolviendo el borrador. Al descartarla devuelve null.
class MembersFilterSheet extends ConsumerStatefulWidget {
  const MembersFilterSheet({
    super.key,
    required this.initial,
    required this.classes,
    required this.roles,
  });

  final MemberFilters initial;
  final List<String> classes;
  final List<String> roles;

  /// Alto máximo de la hoja como fracción de la pantalla.
  static const double maxHeightFactor = 0.85;

  @override
  ConsumerState<MembersFilterSheet> createState() => _MembersFilterSheetState();
}

class _MembersFilterSheetState extends ConsumerState<MembersFilterSheet> {
  late MemberFilters _draft = widget.initial;

  void _toggleClass(String option) {
    setState(() {
      _draft = _draft.classFilter == option
          ? _draft.copyWith(clearClass: true)
          : _draft.copyWith(classFilter: option);
    });
  }

  void _toggleRole(String option) {
    setState(() {
      _draft = _draft.roleFilter == option
          ? _draft.copyWith(clearRole: true)
          : _draft.copyWith(roleFilter: option);
    });
  }

  void _setEnrolled(bool? value) {
    setState(() {
      _draft = value == null
          ? _draft.copyWith(clearEnrolled: true)
          : _draft.copyWith(enrolledFilter: value);
    });
  }

  void _clearDraft() {
    setState(() {
      _draft = _draft.copyWith(
        clearClass: true,
        clearRole: true,
        clearEnrolled: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final media = MediaQuery.of(context);
    final allMembers =
        ref.watch(membersNotifierProvider).value?.members ?? const [];
    // Mismo cálculo que filteredMembersProvider.
    final count = _draft.applyTo(allMembers).length;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: media.size.height * MembersFilterSheet.maxHeightFactor,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLG),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // Stretch so the sections start at the left padding, not centered.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Container(
              alignment: Alignment.center,
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(AppTheme.radiusHairline),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Semantics(
                header: true,
                child: Text(
                  'members.filter_bar.sheet_title'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: SacFontSize.titleMedium,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.classes.isNotEmpty)
                      _Section(
                        label: 'members.filter_bar.class_filter'.tr(),
                        children: [
                          for (final option in widget.classes)
                            SacFilterChip(
                              label: option,
                              selected: _draft.classFilter == option,
                              logoAsset: memberFilterClassLogo(option),
                              logoKey: ValueKey(
                                'member-filter-class-logo-$option',
                              ),
                              logoSize: 20,
                              onTap: () => _toggleClass(option),
                            ),
                        ],
                      ),
                    if (widget.roles.isNotEmpty)
                      _Section(
                        label: 'members.filter_bar.role_filter'.tr(),
                        children: [
                          for (final option in widget.roles)
                            SacFilterChip(
                              label: RoleUtils.translate(option),
                              selected: _draft.roleFilter == option,
                              onTap: () => _toggleRole(option),
                            ),
                        ],
                      ),
                    _Section(
                      label: 'members.filter_bar.enrollment_filter'.tr(),
                      children: [
                        SacFilterChip(
                          label: 'members.filter_bar.enrollment_all'.tr(),
                          selected: _draft.enrolledFilter == null,
                          onTap: () => _setEnrolled(null),
                        ),
                        SacFilterChip(
                          label: 'members.common.not_enrolled'.tr(),
                          selected: _draft.enrolledFilter == false,
                          onTap: () => _setEnrolled(false),
                        ),
                        SacFilterChip(
                          label: 'members.common.enrolled'.tr(),
                          selected: _draft.enrolledFilter == true,
                          onTap: () => _setEnrolled(true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                16 + media.padding.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SacButton(
                      text: 'common.clear'.tr(),
                      variant: SacButtonVariant.outline,
                      fullWidth: true,
                      borderRadius: AppTheme.radiusFull,
                      onPressed: _clearDraft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SacButton(
                      text: 'members.filter_bar.show_members'.plural(count),
                      fullWidth: true,
                      borderRadius: AppTheme.radiusFull,
                      onPressed: () => Navigator.of(context).pop(_draft),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: SacFontSize.labelSmall,
                fontWeight: FontWeight.w700,
                color: c.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Wrap(spacing: 8, children: children),
        ],
      ),
    );
  }
}
