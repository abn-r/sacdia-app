import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/country_model.dart';
import '../../data/models/union_model.dart';
import '../../data/models/local_field_model.dart';
import '../../data/models/club_model.dart';
import '../../data/models/class_model.dart';
import '../providers/club_selection_providers.dart';
import '../providers/post_registration_providers.dart';
import '../widgets/cascading_dropdown.dart';
import '../widgets/club_type_selector.dart';
import '../widgets/class_recommendation.dart';

/// Vista del paso 3 del post-registro: Selección de club
///
/// Permite al usuario seleccionar su ubicación, club y clase progresiva
/// mediante dropdowns en cascada con auto-selección cuando solo hay una opción.
class ClubSelectionStepView extends ConsumerStatefulWidget {
  const ClubSelectionStepView({super.key});

  @override
  ConsumerState<ClubSelectionStepView> createState() =>
      _ClubSelectionStepViewState();
}

class _ClubSelectionStepViewState extends ConsumerState<ClubSelectionStepView> {
  @override
  void initState() {
    super.initState();
    // Aquí se podría cargar la edad del usuario desde el perfil
    // Por ahora dejamos que se establezca externamente
  }

  Future<void> _saveSelection() async {
    final authState = ref.read(authNotifierProvider);
    final user = authState.valueOrNull;
    if (user == null) {
      _showError('Usuario no autenticado');
      return;
    }

    final countryId = ref.read(selectedCountryProvider);
    final unionId = ref.read(selectedUnionProvider);
    final localFieldId = ref.read(selectedLocalFieldProvider);
    final clubInstanceId = ref.read(selectedClubInstanceProvider);
    final classId = ref.read(selectedClassProvider);

    if (countryId == null ||
        unionId == null ||
        localFieldId == null ||
        clubInstanceId == null ||
        classId == null) {
      _showError('Por favor completa todos los campos');
      return;
    }

    ref.read(isSavingStep3Provider.notifier).state = true;
    ref.read(step3ErrorProvider.notifier).state = null;

    try {
      final dataSource = ref.read(clubSelectionDataSourceProvider);
      await dataSource.completeStep3(
        userId: user.id,
        countryId: countryId,
        unionId: unionId,
        localFieldId: localFieldId,
        clubInstanceId: clubInstanceId,
        classId: classId,
      );

      if (mounted) {
        // Refrescar el estado de completitud
        await ref.read(completionStatusProvider.notifier).refresh();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Información guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      log('Error al guardar selección de club: $e');
      ref.read(step3ErrorProvider.notifier).state = e.toString();
      _showError('Error al guardar la información: $e');
    } finally {
      if (mounted) {
        ref.read(isSavingStep3Provider.notifier).state = false;
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

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
    final canComplete = ref.watch(canCompleteStep3Provider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título y descripción
          Text(
            'Selecciona tu Club',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Por favor completa la siguiente información para asociarte a tu club.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),

          // País
          countriesAsync.when(
            data: (countries) {
              return CascadingDropdown<CountryModel>(
                label: 'País',
                items: countries,
                selectedValue: countries.firstWhere(
                  (c) => c.id == selectedCountryId,
                  orElse: () => countries.first,
                ),
                onChanged: (country) {
                  if (country != null) {
                    ref.read(selectedCountryProvider.notifier).state = country.id;
                    // Reset siguiente nivel
                    ref.read(selectedUnionProvider.notifier).state = null;
                    ref.read(selectedLocalFieldProvider.notifier).state = null;
                    ref.read(selectedClubProvider.notifier).state = null;
                    ref.read(selectedClubInstanceProvider.notifier).state = null;
                    ref.read(selectedClassProvider.notifier).state = null;
                  }
                },
                getItemLabel: (country) => country.name,
                getItemValue: (country) => country.id,
                isEnabled: !isSaving,
              );
            },
            loading: () => CascadingDropdown(
              label: 'País',
              items: [],
              selectedValue: null,
              onChanged: null,
              getItemLabel: (_) => '',
              getItemValue: (_) => null,
              isLoading: true,
            ),
            error: (error, stack) => Text(
              'Error al cargar países: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
          const SizedBox(height: 24),

          // Unión
          if (selectedCountryId != null)
            unionsAsync.when(
              data: (unions) {
                if (unions.isEmpty) {
                  return const Text(
                    'No hay uniones disponibles para este país',
                    style: TextStyle(color: Colors.grey),
                  );
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
                      // Reset siguiente nivel
                      ref.read(selectedLocalFieldProvider.notifier).state = null;
                      ref.read(selectedClubProvider.notifier).state = null;
                      ref.read(selectedClubInstanceProvider.notifier).state = null;
                      ref.read(selectedClassProvider.notifier).state = null;
                    }
                  },
                  getItemLabel: (union) => union.name,
                  getItemValue: (union) => union.id,
                  isEnabled: !isSaving,
                );
              },
              loading: () => CascadingDropdown(
                label: 'Unión',
                items: [],
                selectedValue: null,
                onChanged: null,
                getItemLabel: (_) => '',
                getItemValue: (_) => null,
                isLoading: true,
              ),
              error: (error, stack) => Text(
                'Error al cargar uniones: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (selectedCountryId != null) const SizedBox(height: 24),

          // Campo Local
          if (selectedUnionId != null)
            localFieldsAsync.when(
              data: (localFields) {
                if (localFields.isEmpty) {
                  return const Text(
                    'No hay campos locales disponibles para esta unión',
                    style: TextStyle(color: Colors.grey),
                  );
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
                      // Reset siguiente nivel
                      ref.read(selectedClubProvider.notifier).state = null;
                      ref.read(selectedClubInstanceProvider.notifier).state = null;
                      ref.read(selectedClassProvider.notifier).state = null;
                    }
                  },
                  getItemLabel: (localField) => localField.name,
                  getItemValue: (localField) => localField.id,
                  isEnabled: !isSaving,
                );
              },
              loading: () => CascadingDropdown(
                label: 'Campo Local',
                items: [],
                selectedValue: null,
                onChanged: null,
                getItemLabel: (_) => '',
                getItemValue: (_) => null,
                isLoading: true,
              ),
              error: (error, stack) => Text(
                'Error al cargar campos locales: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (selectedUnionId != null) const SizedBox(height: 24),

          // Club
          if (selectedLocalFieldId != null)
            clubsAsync.when(
              data: (clubs) {
                if (clubs.isEmpty) {
                  return const Text(
                    'No hay clubes disponibles para este campo local',
                    style: TextStyle(color: Colors.grey),
                  );
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
                      // Reset siguiente nivel
                      ref.read(selectedClubInstanceProvider.notifier).state = null;
                      ref.read(selectedClassProvider.notifier).state = null;
                    }
                  },
                  getItemLabel: (club) => club.name,
                  getItemValue: (club) => club.id,
                  isEnabled: !isSaving,
                );
              },
              loading: () => CascadingDropdown(
                label: 'Club',
                items: [],
                selectedValue: null,
                onChanged: null,
                getItemLabel: (_) => '',
                getItemValue: (_) => null,
                isLoading: true,
              ),
              error: (error, stack) => Text(
                'Error al cargar clubes: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (selectedLocalFieldId != null) const SizedBox(height: 24),

          // Tipo de Club
          if (selectedClubId != null) const ClubTypeSelector(),
          if (selectedClubId != null) const SizedBox(height: 24),

          // Clase Progresiva
          if (ref.watch(selectedClubInstanceProvider) != null) ...[
            const ClassRecommendation(),
            classesAsync.when(
              data: (classes) {
                if (classes.isEmpty) {
                  return const Text(
                    'No hay clases disponibles para este tipo de club',
                    style: TextStyle(color: Colors.grey),
                  );
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
              loading: () => CascadingDropdown(
                label: 'Clase Progresiva',
                items: [],
                selectedValue: null,
                onChanged: null,
                getItemLabel: (_) => '',
                getItemValue: (_) => null,
                isLoading: true,
              ),
              error: (error, stack) => Text(
                'Error al cargar clases: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Botón de guardar
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: canComplete && !isSaving ? _saveSelection : null,
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar y Continuar'),
            ),
          ),
        ],
      ),
    );
  }
}
