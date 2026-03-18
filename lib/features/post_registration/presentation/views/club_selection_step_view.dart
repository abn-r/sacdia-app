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
import '../widgets/cascading_dropdown.dart';
import '../widgets/club_type_selector.dart';
import '../widgets/class_recommendation.dart';

/// Vista del paso 3: Selección de club - Estilo "Scout Vibrante"
///
/// Dropdowns en cascada para ubicación, club y clase progresiva.
/// Sin Scaffold interno, usa SacCard para contenedores.
/// Title uses responsive font size for small phones.
class ClubSelectionStepView extends ConsumerStatefulWidget {
  const ClubSelectionStepView({super.key});

  @override
  ConsumerState<ClubSelectionStepView> createState() =>
      _ClubSelectionStepViewState();
}

class _ClubSelectionStepViewState extends ConsumerState<ClubSelectionStepView> {
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

          // Location icon header
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

          // Country
          countriesAsync.when(
            data: (countries) => CascadingDropdown<CountryModel>(
              label: 'País',
              items: countries,
              selectedValue: countries.firstWhere(
                (c) => c.id == selectedCountryId,
                orElse: () => countries.first,
              ),
              onChanged: (country) {
                if (country != null) {
                  ref.read(selectedCountryProvider.notifier).state = country.id;
                  ref.read(selectedUnionProvider.notifier).state = null;
                  ref.read(selectedLocalFieldProvider.notifier).state = null;
                  ref.read(selectedClubProvider.notifier).state = null;
                  ref.read(selectedClubSectionProvider.notifier).state = null;
                  ref.read(selectedClassProvider.notifier).state = null;
                }
              },
              getItemLabel: (country) => country.name,
              getItemValue: (country) => country.id,
              isEnabled: !isSaving,
            ),
            loading: () => _buildLoadingDropdown('País'),
            error: (error, stack) =>
                _buildErrorText('Error al cargar países: $error'),
          ),
          const SizedBox(height: 16),

          // Union
          if (selectedCountryId != null)
            unionsAsync.when(
              data: (unions) {
                if (unions.isEmpty) {
                  return _buildEmptyText('No hay uniones disponibles');
                }
                return CascadingDropdown<UnionModel>(
                  label: 'Unión',
                  items: unions,
                  selectedValue: selectedUnionId != null
                      ? unions.firstWhere(
                          (u) => u.id == selectedUnionId,
                          orElse: () => unions.first,
                        )
                      : null,
                  onChanged: (union) {
                    if (union != null) {
                      ref.read(selectedUnionProvider.notifier).state = union.id;
                      ref.read(selectedLocalFieldProvider.notifier).state =
                          null;
                      ref.read(selectedClubProvider.notifier).state = null;
                      ref.read(selectedClubSectionProvider.notifier).state =
                          null;
                      ref.read(selectedClassProvider.notifier).state = null;
                    }
                  },
                  getItemLabel: (union) => union.name,
                  getItemValue: (union) => union.id,
                  isEnabled: !isSaving,
                );
              },
              loading: () => _buildLoadingDropdown('Unión'),
              error: (error, stack) =>
                  _buildErrorText('Error al cargar uniones: $error'),
            ),
          if (selectedCountryId != null) const SizedBox(height: 16),

          // Local Field
          if (selectedUnionId != null)
            localFieldsAsync.when(
              data: (localFields) {
                if (localFields.isEmpty) {
                  return _buildEmptyText('No hay campos locales disponibles');
                }
                return CascadingDropdown<LocalFieldModel>(
                  label: 'Campo Local',
                  items: localFields,
                  selectedValue: selectedLocalFieldId != null
                      ? localFields.firstWhere(
                          (lf) => lf.id == selectedLocalFieldId,
                          orElse: () => localFields.first,
                        )
                      : null,
                  onChanged: (localField) {
                    if (localField != null) {
                      ref.read(selectedLocalFieldProvider.notifier).state =
                          localField.id;
                      ref.read(selectedClubProvider.notifier).state = null;
                      ref.read(selectedClubSectionProvider.notifier).state =
                          null;
                      ref.read(selectedClassProvider.notifier).state = null;
                    }
                  },
                  getItemLabel: (localField) => localField.name,
                  getItemValue: (localField) => localField.id,
                  isEnabled: !isSaving,
                );
              },
              loading: () => _buildLoadingDropdown('Campo Local'),
              error: (error, stack) =>
                  _buildErrorText('Error al cargar campos locales: $error'),
            ),
          if (selectedUnionId != null) const SizedBox(height: 24),

          // Club section
          if (selectedLocalFieldId != null) ...[
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
                return CascadingDropdown<ClubModel>(
                  label: 'Club',
                  items: clubs,
                  selectedValue: selectedClubId != null
                      ? clubs.firstWhere(
                          (c) => c.id == selectedClubId,
                          orElse: () => clubs.first,
                        )
                      : null,
                  onChanged: (club) {
                    if (club != null) {
                      ref.read(selectedClubProvider.notifier).state = club.id;
                      // Resetear instancia y clase al cambiar de club
                      // (selectedClubTypeSlugProvider se deriva automáticamente)
                      ref.read(selectedClubSectionProvider.notifier).state =
                          null;
                      ref.read(selectedClassProvider.notifier).state = null;
                    }
                  },
                  getItemLabel: (club) => club.name,
                  getItemValue: (club) => club.id,
                  isEnabled: !isSaving,
                );
              },
              loading: () => _buildLoadingDropdown('Club'),
              error: (error, stack) =>
                  _buildErrorText('Error al cargar clubes: $error'),
            ),
            const SizedBox(height: 16),
          ],

          // Tipo de Club
          if (selectedClubId != null) ...[
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
            const SizedBox(height: 24),
          ],

          // Class
          if (ref.watch(selectedClubSectionProvider) != null) ...[
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
                return CascadingDropdown<ClassModel>(
                  label: 'Clase Progresiva',
                  items: classes,
                  selectedValue: selectedClassId != null
                      ? classes.firstWhere(
                          (c) => c.id == selectedClassId,
                          orElse: () => classes.first,
                        )
                      : null,
                  onChanged: (classModel) {
                    if (classModel != null) {
                      ref.read(selectedClassProvider.notifier).state =
                          classModel.id;
                    }
                  },
                  getItemLabel: (classModel) => classModel.name,
                  getItemValue: (classModel) => classModel.id,
                  isEnabled: !isSaving,
                );
              },
              loading: () => _buildLoadingDropdown('Clase Progresiva'),
              error: (error, stack) =>
                  _buildErrorText('Error al cargar clases: $error'),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLoadingDropdown(String label) {
    return CascadingDropdown(
      label: label,
      items: const [],
      selectedValue: null,
      onChanged: null,
      getItemLabel: (_) => '',
      getItemValue: (_) => null,
      isLoading: true,
    );
  }

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
