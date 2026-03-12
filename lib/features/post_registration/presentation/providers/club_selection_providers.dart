import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/club_selection_remote_data_source.dart';
import '../../data/models/country_model.dart';
import '../../data/models/union_model.dart';
import '../../data/models/local_field_model.dart';
import '../../data/models/club_model.dart';
import '../../data/models/club_instance_model.dart';
import '../../data/models/class_model.dart';

/// Provider para la fuente de datos remota de selección de club
final clubSelectionDataSourceProvider =
    Provider<ClubSelectionRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  return ClubSelectionRemoteDataSourceImpl(
    dio: dio,
    baseUrl: AppConstants.baseUrl,
  );
});

/// Provider para la edad del usuario
/// Este valor debe ser establecido desde la información del usuario
final userAgeProvider = StateProvider<int?>((ref) => null);

// ─────────────────────────────────────────────────────────────────────────────
// DATA PROVIDERS — fetch data only, no side effects
// ─────────────────────────────────────────────────────────────────────────────

/// Provider para obtener la lista de países
final countriesProvider = FutureProvider<List<CountryModel>>((ref) async {
  final dataSource = ref.read(clubSelectionDataSourceProvider);
  return dataSource.getCountries();
});

/// Provider para obtener las uniones del país seleccionado
final unionsProvider = FutureProvider<List<UnionModel>>((ref) async {
  final countryId = ref.watch(selectedCountryProvider);
  if (countryId == null) return [];

  final dataSource = ref.read(clubSelectionDataSourceProvider);
  return dataSource.getUnionsByCountry(countryId);
});

/// Provider para obtener los campos locales de la unión seleccionada
final localFieldsProvider = FutureProvider<List<LocalFieldModel>>((ref) async {
  final unionId = ref.watch(selectedUnionProvider);
  if (unionId == null) return [];

  final dataSource = ref.read(clubSelectionDataSourceProvider);
  return dataSource.getLocalFieldsByUnion(unionId);
});

/// Provider para obtener los clubes del campo local seleccionado
final clubsProvider = FutureProvider<List<ClubModel>>((ref) async {
  final localFieldId = ref.watch(selectedLocalFieldProvider);
  if (localFieldId == null) return [];

  final dataSource = ref.read(clubSelectionDataSourceProvider);
  return dataSource.getClubsByLocalField(localFieldId);
});

/// Provider para obtener las instancias (tipos) del club seleccionado
final clubInstancesProvider =
    FutureProvider<List<ClubInstanceModel>>((ref) async {
  final clubId = ref.watch(selectedClubProvider);
  if (clubId == null) return [];

  final dataSource = ref.read(clubSelectionDataSourceProvider);
  return dataSource.getClubInstances(clubId);
});

/// Provider para obtener las clases del tipo de club seleccionado
final classesProvider = FutureProvider<List<ClassModel>>((ref) async {
  final clubInstanceId = ref.watch(selectedClubInstanceProvider);
  if (clubInstanceId == null) return [];

  // Obtener el clubTypeId de la instancia seleccionada
  final instancesAsync = ref.watch(clubInstancesProvider);
  final clubTypeId = instancesAsync.maybeWhen(
    data: (instances) {
      final instance = instances.firstWhere(
        (i) => i.id == clubInstanceId,
        orElse: () => instances.first,
      );
      return instance.clubTypeId;
    },
    orElse: () => null,
  );

  if (clubTypeId == null) return [];

  final dataSource = ref.read(clubSelectionDataSourceProvider);
  return dataSource.getClassesByClubType(clubTypeId);
});

// ─────────────────────────────────────────────────────────────────────────────
// SELECTION PROVIDERS — derive initial value from data, allow user override
//
// Pattern: StateProvider watches its data provider so that when the data
// loads (or reloads because a parent selection changed), the provider
// rebuilds and returns the auto-selected value. When the user manually
// writes a value via `.notifier`, that overrides the computed initial value
// until the data provider itself rebuilds.
// ─────────────────────────────────────────────────────────────────────────────

/// Provider para el país seleccionado.
/// Auto-selecciona el único país si la lista tiene exactamente uno.
final selectedCountryProvider = StateProvider<int?>((ref) {
  final countries = ref.watch(countriesProvider).valueOrNull;
  if (countries != null && countries.length == 1) {
    return countries.first.id;
  }
  return null;
});

/// Provider para la unión seleccionada.
/// Auto-selecciona la única unión si la lista tiene exactamente una.
final selectedUnionProvider = StateProvider<int?>((ref) {
  final unions = ref.watch(unionsProvider).valueOrNull;
  if (unions != null && unions.length == 1) {
    return unions.first.id;
  }
  return null;
});

/// Provider para el campo local seleccionado.
/// Auto-selecciona el único campo local si la lista tiene exactamente uno.
final selectedLocalFieldProvider = StateProvider<int?>((ref) {
  final localFields = ref.watch(localFieldsProvider).valueOrNull;
  if (localFields != null && localFields.length == 1) {
    return localFields.first.id;
  }
  return null;
});

/// Provider para el club seleccionado.
/// Auto-selecciona el único club si la lista tiene exactamente uno.
final selectedClubProvider = StateProvider<int?>((ref) {
  final clubs = ref.watch(clubsProvider).valueOrNull;
  if (clubs != null && clubs.length == 1) {
    return clubs.first.id;
  }
  return null;
});

/// Provider para la instancia de club seleccionada.
/// Auto-selecciona considerando:
///   1. Única instancia disponible → se selecciona directamente.
///   2. Múltiples instancias + edad conocida → pre-selección por rango etario.
///   3. Sin datos o edad desconocida → null.
final selectedClubInstanceProvider = StateProvider<int?>((ref) {
  final instances = ref.watch(clubInstancesProvider).valueOrNull;
  if (instances == null || instances.isEmpty) return null;

  if (instances.length == 1) return instances.first.id;

  final age = ref.watch(userAgeProvider);
  if (age == null) return null;

  ClubInstanceModel? recommended;
  if (age >= 4 && age <= 9) {
    recommended = instances.firstWhere(
      (instance) =>
          instance.clubTypeSlug == 'adventurers' ||
          (instance.clubTypeName?.toLowerCase().contains('aventurero') ?? false),
      orElse: () => instances.first,
    );
  } else if (age >= 10 && age <= 15) {
    recommended = instances.firstWhere(
      (instance) =>
          instance.clubTypeSlug == 'pathfinders' ||
          (instance.clubTypeName?.toLowerCase().contains('conquistador') ??
              false),
      orElse: () => instances.first,
    );
  } else if (age >= 16) {
    recommended = instances.firstWhere(
      (instance) =>
          instance.clubTypeSlug == 'master_guild' ||
          (instance.clubTypeName?.toLowerCase().contains('guía') ?? false),
      orElse: () => instances.first,
    );
  }

  return recommended?.id;
});

/// Provider para el slug del tipo de club de la instancia seleccionada.
/// Valores posibles: 'adventurers' | 'pathfinders' | 'master_guild' | null.
///
/// Derivado automáticamente de [selectedClubInstanceProvider] y
/// [clubInstancesProvider] — no requiere escritura manual.
final selectedClubTypeSlugProvider = Provider<String?>((ref) {
  final selectedId = ref.watch(selectedClubInstanceProvider);
  if (selectedId == null) return null;

  final instances = ref.watch(clubInstancesProvider).valueOrNull;
  if (instances == null || instances.isEmpty) return null;

  final instance = instances.where((i) => i.id == selectedId).firstOrNull;
  return instance?.clubTypeSlug;
});

/// Provider para la clase seleccionada.
/// Auto-selecciona considerando:
///   1. Única clase disponible → se selecciona directamente.
///   2. Múltiples clases + edad conocida → clase cuyo rango etario coincide.
///   3. Sin datos o sin coincidencia → null.
final selectedClassProvider = StateProvider<int?>((ref) {
  final classes = ref.watch(classesProvider).valueOrNull;
  if (classes == null || classes.isEmpty) return null;

  if (classes.length == 1) return classes.first.id;

  final age = ref.watch(userAgeProvider);
  if (age == null) return null;

  final recommended = classes.where((classModel) {
    if (classModel.minAge != null && classModel.maxAge != null) {
      return age >= classModel.minAge! && age <= classModel.maxAge!;
    }
    return false;
  }).firstOrNull;

  return recommended?.id;
});

// ─────────────────────────────────────────────────────────────────────────────
// FORM STATE PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Provider para determinar si se puede completar el paso 3
final canCompleteStep3Provider = Provider<bool>((ref) {
  final country = ref.watch(selectedCountryProvider);
  final union = ref.watch(selectedUnionProvider);
  final localField = ref.watch(selectedLocalFieldProvider);
  final clubInstance = ref.watch(selectedClubInstanceProvider);
  final classId = ref.watch(selectedClassProvider);
  final clubTypeSlug = ref.watch(selectedClubTypeSlugProvider);

  return country != null &&
      union != null &&
      localField != null &&
      clubInstance != null &&
      classId != null &&
      clubTypeSlug != null;
});

/// Provider para indicar si se está guardando el paso 3
final isSavingStep3Provider = StateProvider<bool>((ref) => false);

/// Provider para el mensaje de error del paso 3
final step3ErrorProvider = StateProvider<String?>((ref) => null);
