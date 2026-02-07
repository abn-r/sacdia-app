import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
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

/// Provider para obtener la lista de países
final countriesProvider = FutureProvider<List<CountryModel>>((ref) async {
  final dataSource = ref.read(clubSelectionDataSourceProvider);
  final countries = await dataSource.getCountries();

  // Auto-selección si solo hay un país
  if (countries.length == 1) {
    Future.microtask(() {
      ref.read(selectedCountryProvider.notifier).state = countries.first.id;
    });
  }

  return countries;
});

/// Provider para el país seleccionado
final selectedCountryProvider = StateProvider<int?>((ref) => null);

/// Provider para obtener las uniones del país seleccionado
final unionsProvider = FutureProvider<List<UnionModel>>((ref) async {
  final countryId = ref.watch(selectedCountryProvider);
  if (countryId == null) return [];

  final dataSource = ref.read(clubSelectionDataSourceProvider);
  final unions = await dataSource.getUnionsByCountry(countryId);

  // Auto-selección si solo hay una unión
  if (unions.length == 1) {
    Future.microtask(() {
      ref.read(selectedUnionProvider.notifier).state = unions.first.id;
    });
  }

  return unions;
});

/// Provider para la unión seleccionada
final selectedUnionProvider = StateProvider<int?>((ref) => null);

/// Provider para obtener los campos locales de la unión seleccionada
final localFieldsProvider = FutureProvider<List<LocalFieldModel>>((ref) async {
  final unionId = ref.watch(selectedUnionProvider);
  if (unionId == null) return [];

  final dataSource = ref.read(clubSelectionDataSourceProvider);
  final localFields = await dataSource.getLocalFieldsByUnion(unionId);

  // Auto-selección si solo hay un campo local
  if (localFields.length == 1) {
    Future.microtask(() {
      ref.read(selectedLocalFieldProvider.notifier).state = localFields.first.id;
    });
  }

  return localFields;
});

/// Provider para el campo local seleccionado
final selectedLocalFieldProvider = StateProvider<int?>((ref) => null);

/// Provider para obtener los clubes del campo local seleccionado
final clubsProvider = FutureProvider<List<ClubModel>>((ref) async {
  final localFieldId = ref.watch(selectedLocalFieldProvider);
  if (localFieldId == null) return [];

  final dataSource = ref.read(clubSelectionDataSourceProvider);
  final clubs = await dataSource.getClubsByLocalField(localFieldId);

  // Auto-selección si solo hay un club
  if (clubs.length == 1) {
    Future.microtask(() {
      ref.read(selectedClubProvider.notifier).state = clubs.first.id;
    });
  }

  return clubs;
});

/// Provider para el club seleccionado
final selectedClubProvider = StateProvider<int?>((ref) => null);

/// Provider para obtener las instancias (tipos) del club seleccionado
final clubInstancesProvider = FutureProvider<List<ClubInstanceModel>>((ref) async {
  final clubId = ref.watch(selectedClubProvider);
  if (clubId == null) return [];

  final dataSource = ref.read(clubSelectionDataSourceProvider);
  final instances = await dataSource.getClubInstances(clubId);

  // Auto-selección basada en edad si está disponible
  final age = ref.read(userAgeProvider);
  if (instances.length == 1) {
    Future.microtask(() {
      ref.read(selectedClubInstanceProvider.notifier).state = instances.first.id;
    });
  } else if (age != null && instances.isNotEmpty) {
    // Pre-selección basada en edad
    ClubInstanceModel? recommended;
    if (age >= 4 && age <= 9) {
      recommended = instances.firstWhere(
        (instance) => instance.clubTypeName.toLowerCase().contains('aventurero'),
        orElse: () => instances.first,
      );
    } else if (age >= 10 && age <= 15) {
      recommended = instances.firstWhere(
        (instance) => instance.clubTypeName.toLowerCase().contains('conquistador'),
        orElse: () => instances.first,
      );
    } else if (age >= 16) {
      recommended = instances.firstWhere(
        (instance) => instance.clubTypeName.toLowerCase().contains('guía'),
        orElse: () => instances.first,
      );
    }

    if (recommended != null) {
      Future.microtask(() {
        ref.read(selectedClubInstanceProvider.notifier).state = recommended!.id;
      });
    }
  }

  return instances;
});

/// Provider para la instancia de club seleccionada
final selectedClubInstanceProvider = StateProvider<int?>((ref) => null);

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
  final classes = await dataSource.getClassesByClubType(clubTypeId);

  // Auto-selección basada en edad si está disponible
  final age = ref.read(userAgeProvider);
  if (classes.length == 1) {
    Future.microtask(() {
      ref.read(selectedClassProvider.notifier).state = classes.first.id;
    });
  } else if (age != null && classes.isNotEmpty) {
    // Buscar clase que coincida con la edad
    final recommended = classes.firstWhere(
      (classModel) {
        if (classModel.minAge != null && classModel.maxAge != null) {
          return age >= classModel.minAge! && age <= classModel.maxAge!;
        }
        return false;
      },
      orElse: () => classes.first,
    );

    Future.microtask(() {
      ref.read(selectedClassProvider.notifier).state = recommended.id;
    });
  }

  return classes;
});

/// Provider para la clase seleccionada
final selectedClassProvider = StateProvider<int?>((ref) => null);

/// Provider para determinar si se puede completar el paso 3
final canCompleteStep3Provider = Provider<bool>((ref) {
  final country = ref.watch(selectedCountryProvider);
  final union = ref.watch(selectedUnionProvider);
  final localField = ref.watch(selectedLocalFieldProvider);
  final clubInstance = ref.watch(selectedClubInstanceProvider);
  final classId = ref.watch(selectedClassProvider);

  return country != null &&
      union != null &&
      localField != null &&
      clubInstance != null &&
      classId != null;
});

/// Provider para indicar si se está guardando el paso 3
final isSavingStep3Provider = StateProvider<bool>((ref) => false);

/// Provider para el mensaje de error del paso 3
final step3ErrorProvider = StateProvider<String?>((ref) => null);
