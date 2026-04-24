import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import '../../data/models/country_model.dart';
import '../../data/models/union_model.dart';
import '../../data/models/local_field_model.dart';
import '../../data/models/club_model.dart';
import '../../data/models/class_model.dart';
import '../providers/club_selection_providers.dart';
import '../widgets/bottom_sheet_picker.dart';
import '../widgets/club_type_selector.dart';
import '../widgets/class_recommendation.dart';

/// Vista del paso 3: Selección de club - Estilo "Scout Vibrante"
///
/// Pickers en cascada (bottom sheet modal) para ubicación, club y clase
/// progresiva. Sin Scaffold interno, usa SacCard para contenedores.
/// Title uses responsive font size for small phones.
class ClubSelectionStepView extends ConsumerStatefulWidget {
  const ClubSelectionStepView({super.key});

  @override
  ConsumerState<ClubSelectionStepView> createState() =>
      _ClubSelectionStepViewState();
}

class _ClubSelectionStepViewState extends ConsumerState<ClubSelectionStepView> {
  // ─── helpers ────────────────────────────────────────────────────────────────

  List<PickerItem> _toPickerItems<T>(
    List<T> items,
    int Function(T) getId,
    String Function(T) getName,
  ) =>
      items.map((e) => PickerItem(id: getId(e), name: getName(e))).toList();

  // ─── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final countriesAsync = ref.watch(countriesProvider);
    final unionsAsync = ref.watch(unionsProvider);
    final localFieldsAsync = ref.watch(localFieldsProvider);
    final clubsAsync = ref.watch(clubsProvider);
    final classesAsync = ref.watch(classesProvider);

    final selectedCountryId = ref.watch(selectedCountryProvider);
    final selectedUnionId = ref.watch(selectedUnionProvider);
    final selectedLocalFieldId = ref.watch(selectedLocalFieldProvider);
    final selectedClubId = ref.watch(selectedClubProvider);
    final selectedClassId = ref.watch(selectedClassProvider);

    final isSaving = ref.watch(isSavingStep3Provider);

    // Resolved display names for the fields
    final selectedCountryName = countriesAsync.valueOrNull
        ?.where((c) => c.id == selectedCountryId)
        .map((c) => c.name)
        .firstOrNull;

    final selectedUnionName = unionsAsync.valueOrNull
        ?.where((u) => u.id == selectedUnionId)
        .map((u) => u.name)
        .firstOrNull;

    final selectedLocalFieldName = localFieldsAsync.valueOrNull
        ?.where((lf) => lf.id == selectedLocalFieldId)
        .map((lf) => lf.name)
        .firstOrNull;

    final selectedClubName = clubsAsync.valueOrNull
        ?.where((c) => c.id == selectedClubId)
        .map((c) => c.name)
        .firstOrNull;

    final selectedClassName = classesAsync.valueOrNull
        ?.where((c) => c.id == selectedClassId)
        .map((c) => c.name)
        .firstOrNull;

    // Responsive title style — smaller on very small phones
    final titleStyle = Responsive.isSmallPhone(context)
        ? Theme.of(context).textTheme.headlineLarge
        : Theme.of(context).textTheme.displayMedium;

    final hPad = Responsive.horizontalPadding(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Title
          Text(
            'post_registration.club_selection.title'.tr(),
            style: titleStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'post_registration.club_selection.subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.sac.textSecondary,
                ),
          ),
          const SizedBox(height: 32),

          // ── Location section header ──────────────────────────────────────
          Row(
            children: [
              HugeIcon(
                  icon: HugeIcons.strokeRoundedLocation01,
                  size: 20,
                  color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'post_registration.club_selection.location'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── País ────────────────────────────────────────────────────────
          countriesAsync.when(
            data: (countries) {
              final items = _toPickerItems<CountryModel>(
                  countries, (c) => c.id, (c) => c.name);
              return PickerField(
                label: 'post_registration.club_selection.country'.tr(),
                hint: 'post_registration.club_selection.select_country'.tr(),
                icon: Icons.public_rounded,
                selectedName: selectedCountryName,
                enabled: !isSaving,
                onTap: () async {
                  final picked = await showPickerSheet(
                    context: context,
                    title: 'post_registration.club_selection.select_country'.tr(),
                    items: items,
                    selectedId: selectedCountryId,
                    searchHint: 'post_registration.club_selection.search_country'.tr(),
                    icon: Icons.public_rounded,
                  );
                  if (picked != null && picked != selectedCountryId) {
                    ref.read(selectedCountryProvider.notifier).state = picked;
                    ref.read(selectedUnionProvider.notifier).state = null;
                    ref.read(selectedLocalFieldProvider.notifier).state = null;
                    ref.read(selectedClubProvider.notifier).state = null;
                    ref.read(selectedClubSectionProvider.notifier).state = null;
                    ref.read(selectedClassProvider.notifier).state = null;
                  }
                },
              );
            },
            loading: () => PickerField(
              label: 'post_registration.club_selection.country'.tr(),
              hint: 'post_registration.club_selection.loading_countries'.tr(),
              icon: Icons.public_rounded,
              isLoading: true,
            ),
            error: (error, _) => _buildErrorText(
                'post_registration.club_selection.error_loading_countries'
                    .tr(namedArgs: {'error': error.toString()})),
          ),

          // ── Unión ────────────────────────────────────────────────────────
          if (selectedCountryId != null) ...[
            const SizedBox(height: 16),
            unionsAsync.when(
              data: (unions) {
                if (unions.isEmpty) {
                  return _buildEmptyText(
                      'post_registration.club_selection.no_unions'.tr());
                }
                final items = _toPickerItems<UnionModel>(
                    unions, (u) => u.id, (u) => u.name);
                return PickerField(
                  label: 'post_registration.club_selection.union'.tr(),
                  hint: 'post_registration.club_selection.select_union'.tr(),
                  icon: Icons.account_tree_rounded,
                  selectedName: selectedUnionName,
                  enabled: !isSaving,
                  onTap: () async {
                    final picked = await showPickerSheet(
                      context: context,
                      title: 'post_registration.club_selection.select_union'.tr(),
                      items: items,
                      selectedId: selectedUnionId,
                      searchHint: 'post_registration.club_selection.search_union'.tr(),
                      icon: Icons.account_tree_rounded,
                    );
                    if (picked != null && picked != selectedUnionId) {
                      ref.read(selectedUnionProvider.notifier).state = picked;
                      ref.read(selectedLocalFieldProvider.notifier).state =
                          null;
                      ref.read(selectedClubProvider.notifier).state = null;
                      ref.read(selectedClubSectionProvider.notifier).state =
                          null;
                      ref.read(selectedClassProvider.notifier).state = null;
                    }
                  },
                );
              },
              loading: () => PickerField(
                label: 'post_registration.club_selection.union'.tr(),
                hint: 'post_registration.club_selection.loading_unions'.tr(),
                icon: Icons.account_tree_rounded,
                isLoading: true,
              ),
              error: (error, _) => _buildErrorText(
                  'post_registration.club_selection.error_loading_unions'
                      .tr(namedArgs: {'error': error.toString()})),
            ),
          ],

          // ── Campo Local ──────────────────────────────────────────────────
          if (selectedUnionId != null) ...[
            const SizedBox(height: 16),
            localFieldsAsync.when(
              data: (localFields) {
                if (localFields.isEmpty) {
                  return _buildEmptyText(
                      'post_registration.club_selection.no_local_fields'.tr());
                }
                final items = _toPickerItems<LocalFieldModel>(
                    localFields, (lf) => lf.id, (lf) => lf.name);
                return PickerField(
                  label: 'post_registration.club_selection.local_field'.tr(),
                  hint: 'post_registration.club_selection.select_local_field'.tr(),
                  icon: Icons.place_rounded,
                  selectedName: selectedLocalFieldName,
                  enabled: !isSaving,
                  onTap: () async {
                    final picked = await showPickerSheet(
                      context: context,
                      title: 'post_registration.club_selection.select_local_field'.tr(),
                      items: items,
                      selectedId: selectedLocalFieldId,
                      searchHint:
                          'post_registration.club_selection.search_local_field'.tr(),
                      icon: Icons.place_rounded,
                    );
                    if (picked != null && picked != selectedLocalFieldId) {
                      ref.read(selectedLocalFieldProvider.notifier).state =
                          picked;
                      ref.read(selectedClubProvider.notifier).state = null;
                      ref.read(selectedClubSectionProvider.notifier).state =
                          null;
                      ref.read(selectedClassProvider.notifier).state = null;
                    }
                  },
                );
              },
              loading: () => PickerField(
                label: 'post_registration.club_selection.local_field'.tr(),
                hint: 'post_registration.club_selection.loading_local_fields'.tr(),
                icon: Icons.place_rounded,
                isLoading: true,
              ),
              error: (error, _) => _buildErrorText(
                  'post_registration.club_selection.error_loading_local_fields'
                      .tr(namedArgs: {'error': error.toString()})),
            ),
          ],

          // ── Club section ─────────────────────────────────────────────────
          if (selectedLocalFieldId != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                HugeIcon(
                    icon: HugeIcons.strokeRoundedUserGroup,
                    size: 20,
                    color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'post_registration.club_selection.your_club'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            clubsAsync.when(
              data: (clubs) {
                if (clubs.isEmpty) {
                  return _buildEmptyText(
                      'post_registration.club_selection.no_clubs'.tr());
                }
                final items = _toPickerItems<ClubModel>(
                    clubs, (c) => c.id, (c) => c.name);
                return PickerField(
                  label: 'post_registration.club_selection.club'.tr(),
                  hint: 'post_registration.club_selection.select_club'.tr(),
                  icon: Icons.groups_rounded,
                  selectedName: selectedClubName,
                  enabled: !isSaving,
                  onTap: () async {
                    final picked = await showPickerSheet(
                      context: context,
                      title: 'post_registration.club_selection.select_club'.tr(),
                      items: items,
                      selectedId: selectedClubId,
                      searchHint: 'post_registration.club_selection.search_club'.tr(),
                      icon: Icons.groups_rounded,
                    );
                    if (picked != null && picked != selectedClubId) {
                      ref.read(selectedClubProvider.notifier).state = picked;
                      ref.read(selectedClubSectionProvider.notifier).state =
                          null;
                      ref.read(selectedClassProvider.notifier).state = null;
                    }
                  },
                );
              },
              loading: () => PickerField(
                label: 'post_registration.club_selection.club'.tr(),
                hint: 'post_registration.club_selection.loading_clubs'.tr(),
                icon: Icons.groups_rounded,
                isLoading: true,
              ),
              error: (error, _) => _buildErrorText(
                  'post_registration.club_selection.error_loading_clubs'
                      .tr(namedArgs: {'error': error.toString()})),
            ),
          ],

          // ── Tipo de Club ─────────────────────────────────────────────────
          if (selectedClubId != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                HugeIcon(
                    icon: HugeIcons.strokeRoundedUserGroup,
                    size: 20,
                    color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'post_registration.club_selection.club_type_section'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const ClubTypeSelector(),
          ],

          // ── Clase progresiva ─────────────────────────────────────────────
          if (ref.watch(selectedClubSectionProvider) != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                HugeIcon(
                    icon: HugeIcons.strokeRoundedSchool,
                    size: 20,
                    color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'post_registration.club_selection.your_class'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const ClassRecommendation(),
            const SizedBox(height: 12),
            classesAsync.when(
              data: (classes) {
                if (classes.isEmpty) {
                  return _buildEmptyText(
                      'post_registration.club_selection.no_classes'.tr());
                }
                final items = _toPickerItems<ClassModel>(
                    classes, (c) => c.id, (c) => c.name);
                return PickerField(
                  label: 'post_registration.club_selection.progressive_class'.tr(),
                  hint: 'post_registration.club_selection.select_class'.tr(),
                  icon: Icons.school_rounded,
                  selectedName: selectedClassName,
                  enabled: !isSaving,
                  onTap: () async {
                    final picked = await showPickerSheet(
                      context: context,
                      title: 'post_registration.club_selection.select_progressive_class'
                          .tr(),
                      items: items,
                      selectedId: selectedClassId,
                      searchHint: 'post_registration.club_selection.search_class'.tr(),
                      icon: Icons.school_rounded,
                    );
                    if (picked != null && picked != selectedClassId) {
                      ref.read(selectedClassProvider.notifier).state = picked;
                    }
                  },
                );
              },
              loading: () => PickerField(
                label: 'post_registration.club_selection.progressive_class'.tr(),
                hint: 'post_registration.club_selection.loading_classes'.tr(),
                icon: Icons.school_rounded,
                isLoading: true,
              ),
              error: (error, _) => _buildErrorText(
                  'post_registration.club_selection.error_loading_classes'
                      .tr(namedArgs: {'error': error.toString()})),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── helper widgets ──────────────────────────────────────────────────────────

  Widget _buildErrorText(String message) {
    return SacCard(
      backgroundColor: AppColors.errorLight,
      borderColor: AppColors.error.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(12),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.errorDark, fontSize: 13),
      ),
    );
  }

  Widget _buildEmptyText(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: TextStyle(
          color: context.sac.textTertiary,
          fontSize: 14,
        ),
      ),
    );
  }
}
