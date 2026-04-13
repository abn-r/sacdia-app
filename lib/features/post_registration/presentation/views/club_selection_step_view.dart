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
            'Encuentra tu club',
            style: titleStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona tu ubicación y club para unirte a la aventura',
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
                'Ubicación',
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
                label: 'País',
                hint: 'Seleccionar país',
                icon: Icons.public_rounded,
                selectedName: selectedCountryName,
                enabled: !isSaving,
                onTap: () async {
                  final picked = await showPickerSheet(
                    context: context,
                    title: 'Seleccionar país',
                    items: items,
                    selectedId: selectedCountryId,
                    searchHint: 'Buscar país...',
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
              label: 'País',
              hint: 'Cargando países...',
              icon: Icons.public_rounded,
              isLoading: true,
            ),
            error: (error, _) =>
                _buildErrorText('Error al cargar países: $error'),
          ),

          // ── Unión ────────────────────────────────────────────────────────
          if (selectedCountryId != null) ...[
            const SizedBox(height: 16),
            unionsAsync.when(
              data: (unions) {
                if (unions.isEmpty) {
                  return _buildEmptyText('No hay uniones disponibles');
                }
                final items = _toPickerItems<UnionModel>(
                    unions, (u) => u.id, (u) => u.name);
                return PickerField(
                  label: 'Unión',
                  hint: 'Seleccionar unión',
                  icon: Icons.account_tree_rounded,
                  selectedName: selectedUnionName,
                  enabled: !isSaving,
                  onTap: () async {
                    final picked = await showPickerSheet(
                      context: context,
                      title: 'Seleccionar unión',
                      items: items,
                      selectedId: selectedUnionId,
                      searchHint: 'Buscar unión...',
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
                label: 'Unión',
                hint: 'Cargando uniones...',
                icon: Icons.account_tree_rounded,
                isLoading: true,
              ),
              error: (error, _) =>
                  _buildErrorText('Error al cargar uniones: $error'),
            ),
          ],

          // ── Campo Local ──────────────────────────────────────────────────
          if (selectedUnionId != null) ...[
            const SizedBox(height: 16),
            localFieldsAsync.when(
              data: (localFields) {
                if (localFields.isEmpty) {
                  return _buildEmptyText('No hay campos locales disponibles');
                }
                final items = _toPickerItems<LocalFieldModel>(
                    localFields, (lf) => lf.id, (lf) => lf.name);
                return PickerField(
                  label: 'Campo Local',
                  hint: 'Seleccionar campo local',
                  icon: Icons.place_rounded,
                  selectedName: selectedLocalFieldName,
                  enabled: !isSaving,
                  onTap: () async {
                    final picked = await showPickerSheet(
                      context: context,
                      title: 'Seleccionar campo local',
                      items: items,
                      selectedId: selectedLocalFieldId,
                      searchHint: 'Buscar campo local...',
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
                label: 'Campo Local',
                hint: 'Cargando campos locales...',
                icon: Icons.place_rounded,
                isLoading: true,
              ),
              error: (error, _) =>
                  _buildErrorText('Error al cargar campos locales: $error'),
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
                  'Tu club',
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
                  return _buildEmptyText('No hay clubes disponibles');
                }
                final items = _toPickerItems<ClubModel>(
                    clubs, (c) => c.id, (c) => c.name);
                return PickerField(
                  label: 'Club',
                  hint: 'Seleccionar club',
                  icon: Icons.groups_rounded,
                  selectedName: selectedClubName,
                  enabled: !isSaving,
                  onTap: () async {
                    final picked = await showPickerSheet(
                      context: context,
                      title: 'Seleccionar club',
                      items: items,
                      selectedId: selectedClubId,
                      searchHint: 'Buscar club...',
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
                label: 'Club',
                hint: 'Cargando clubes...',
                icon: Icons.groups_rounded,
                isLoading: true,
              ),
              error: (error, _) =>
                  _buildErrorText('Error al cargar clubes: $error'),
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
                  'Tipo de club',
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
                  'Tu clase',
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
                  return _buildEmptyText('No hay clases disponibles');
                }
                final items = _toPickerItems<ClassModel>(
                    classes, (c) => c.id, (c) => c.name);
                return PickerField(
                  label: 'Clase Progresiva',
                  hint: 'Seleccionar clase',
                  icon: Icons.school_rounded,
                  selectedName: selectedClassName,
                  enabled: !isSaving,
                  onTap: () async {
                    final picked = await showPickerSheet(
                      context: context,
                      title: 'Seleccionar clase progresiva',
                      items: items,
                      selectedId: selectedClassId,
                      searchHint: 'Buscar clase...',
                      icon: Icons.school_rounded,
                    );
                    if (picked != null && picked != selectedClassId) {
                      ref.read(selectedClassProvider.notifier).state = picked;
                    }
                  },
                );
              },
              loading: () => PickerField(
                label: 'Clase Progresiva',
                hint: 'Cargando clases...',
                icon: Icons.school_rounded,
                isLoading: true,
              ),
              error: (error, _) =>
                  _buildErrorText('Error al cargar clases: $error'),
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
