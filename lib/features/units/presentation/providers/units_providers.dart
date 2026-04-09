import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../data/datasources/units_remote_data_source.dart';
import '../../data/models/member_of_month_model.dart';
import '../../data/repositories/units_repository_impl.dart';
import '../../domain/entities/member_of_month.dart';
import '../../domain/entities/scoring_category.dart';
import '../../domain/entities/unit.dart';
import '../../domain/entities/unit_member.dart';
import '../../domain/repositories/units_repository.dart';
import '../../domain/usecases/add_unit_member.dart';
import '../../domain/usecases/create_unit.dart';
import '../../domain/usecases/create_weekly_record.dart';
import '../../domain/usecases/delete_unit.dart';
import '../../domain/usecases/get_club_units.dart';
import '../../domain/usecases/get_member_of_month.dart';
import '../../domain/usecases/get_member_of_month_history.dart';
import '../../domain/usecases/get_scoring_categories.dart';
import '../../domain/usecases/get_unit_detail.dart';
import '../../domain/usecases/get_weekly_records.dart';
import '../../domain/usecases/remove_unit_member.dart';
import '../../domain/usecases/update_unit.dart';
import '../../domain/usecases/update_weekly_record.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────────

final unitsRemoteDataSourceProvider =
    Provider<UnitsRemoteDataSource>((ref) {
  return UnitsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final unitsRepositoryProvider = Provider<UnitsRepository>((ref) {
  return UnitsRepositoryImpl(
    remoteDataSource: ref.read(unitsRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Use cases ──────────────────────────────────────────────────────────────────

final getClubUnitsUseCaseProvider = Provider<GetClubUnits>((ref) {
  return GetClubUnits(ref.read(unitsRepositoryProvider));
});

final getUnitDetailUseCaseProvider = Provider<GetUnitDetail>((ref) {
  return GetUnitDetail(ref.read(unitsRepositoryProvider));
});

final createUnitUseCaseProvider = Provider<CreateUnit>((ref) {
  return CreateUnit(ref.read(unitsRepositoryProvider));
});

final updateUnitUseCaseProvider = Provider<UpdateUnit>((ref) {
  return UpdateUnit(ref.read(unitsRepositoryProvider));
});

final deleteUnitUseCaseProvider = Provider<DeleteUnit>((ref) {
  return DeleteUnit(ref.read(unitsRepositoryProvider));
});

final addUnitMemberUseCaseProvider = Provider<AddUnitMember>((ref) {
  return AddUnitMember(ref.read(unitsRepositoryProvider));
});

final removeUnitMemberUseCaseProvider = Provider<RemoveUnitMember>((ref) {
  return RemoveUnitMember(ref.read(unitsRepositoryProvider));
});

final getWeeklyRecordsUseCaseProvider = Provider<GetWeeklyRecords>((ref) {
  return GetWeeklyRecords(ref.read(unitsRepositoryProvider));
});

final createWeeklyRecordUseCaseProvider = Provider<CreateWeeklyRecord>((ref) {
  return CreateWeeklyRecord(ref.read(unitsRepositoryProvider));
});

final updateWeeklyRecordUseCaseProvider = Provider<UpdateWeeklyRecord>((ref) {
  return UpdateWeeklyRecord(ref.read(unitsRepositoryProvider));
});

final getScoringCategoriesUseCaseProvider = Provider<GetScoringCategories>((ref) {
  return GetScoringCategories(ref.read(unitsRepositoryProvider));
});

final getMemberOfMonthUseCaseProvider = Provider<GetMemberOfMonth>((ref) {
  return GetMemberOfMonth(ref.read(unitsRepositoryProvider));
});

final getMemberOfMonthHistoryUseCaseProvider =
    Provider<GetMemberOfMonthHistory>((ref) {
  return GetMemberOfMonthHistory(ref.read(unitsRepositoryProvider));
});

// ── State ──────────────────────────────────────────────────────────────────────

/// Estado inmutable del feature de unidades.
class UnitsState {
  /// Lista de unidades disponibles para el usuario.
  final List<Unit> units;

  /// Unidad actualmente seleccionada (null = ninguna).
  final Unit? selectedUnit;

  /// Miembros de la unidad seleccionada.
  final List<UnitMember> members;

  /// Puntos pendientes de guardar por miembro y categoría.
  ///
  /// Estructura: memberId → { categoryId → points }
  /// Cuando no hay categorías configuradas, se usa un único key 'default'.
  final Map<String, Map<int, int>> pendingScores;

  /// Si ya se registraron los puntos del día para la unidad activa.
  final bool isSavedToday;

  /// Categorías de puntuación activas para el campo local del club.
  final List<ScoringCategory> categories;

  /// Miembro del Mes actual de la sección (null = no hay datos).
  final MemberOfMonth? memberOfMonth;

  /// Si se está cargando la lista de unidades o miembros.
  final bool isLoading;

  /// Si se está cargando las categorías de puntuación.
  final bool isLoadingCategories;

  /// Si se está cargando el miembro del mes.
  final bool isLoadingMemberOfMonth;

  /// Si se está guardando la sesión de puntos.
  final bool isSaving;

  /// Mensaje de error (null = sin error).
  final String? errorMessage;

  const UnitsState({
    required this.units,
    this.selectedUnit,
    this.members = const [],
    this.pendingScores = const {},
    this.isSavedToday = false,
    this.categories = const [],
    this.memberOfMonth,
    this.isLoading = false,
    this.isLoadingCategories = false,
    this.isLoadingMemberOfMonth = false,
    this.isSaving = false,
    this.errorMessage,
  });

  /// Puntos máximos totales posibles (suma de maxPoints de todas las categorías).
  ///
  /// Usado para la barra de progreso del miembro.
  int get totalMaxPoints {
    if (categories.isEmpty) return 100; // fallback legacy
    return categories.fold(0, (sum, c) => sum + c.maxPoints);
  }

  /// Calcula el total de puntos pendientes para un miembro dado.
  int totalPendingForMember(String memberId) {
    final scores = pendingScores[memberId] ?? {};
    return scores.values.fold(0, (sum, p) => sum + p);
  }

  UnitsState copyWith({
    List<Unit>? units,
    Unit? selectedUnit,
    bool clearSelectedUnit = false,
    List<UnitMember>? members,
    Map<String, Map<int, int>>? pendingScores,
    bool? isSavedToday,
    List<ScoringCategory>? categories,
    MemberOfMonth? memberOfMonth,
    bool clearMemberOfMonth = false,
    bool? isLoading,
    bool? isLoadingCategories,
    bool? isLoadingMemberOfMonth,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UnitsState(
      units: units ?? this.units,
      selectedUnit:
          clearSelectedUnit ? null : (selectedUnit ?? this.selectedUnit),
      members: members ?? this.members,
      pendingScores: pendingScores ?? this.pendingScores,
      isSavedToday: isSavedToday ?? this.isSavedToday,
      categories: categories ?? this.categories,
      memberOfMonth: clearMemberOfMonth
          ? null
          : (memberOfMonth ?? this.memberOfMonth),
      isLoading: isLoading ?? this.isLoading,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isLoadingMemberOfMonth:
          isLoadingMemberOfMonth ?? this.isLoadingMemberOfMonth,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

/// Gestiona el estado del feature de unidades usando la API real.
class UnitsNotifier extends Notifier<UnitsState> {
  @override
  UnitsState build() {
    // Cargar las unidades del club en cuanto se construye el notifier.
    _loadUnits();
    return const UnitsState(units: []);
  }

  // ── Carga inicial ────────────────────────────────────────────────────────

  Future<void> _loadUnits() async {
    final ctx = await ref.read(clubContextProvider.future);
    if (ctx == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    // Cargar unidades y miembro del mes en paralelo
    final unitsFuture = ref
        .read(getClubUnitsUseCaseProvider)
        .call(GetClubUnitsParams(clubId: ctx.clubId));

    final memberOfMonthFuture = ref
        .read(getMemberOfMonthUseCaseProvider)
        .call(GetMemberOfMonthParams(
          clubId: ctx.clubId,
          sectionId: ctx.sectionId,
        ));

    final results = await Future.wait([unitsFuture, memberOfMonthFuture]);
    final unitsResult = results[0] as dynamic;
    final momResult = results[1] as dynamic;

    // Procesar unidades
    unitsResult.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (units) {
        state = state.copyWith(
          isLoading: false,
          units: units as List<Unit>,
        );
      },
    );

    // Procesar miembro del mes (errores no bloquean la vista)
    momResult.fold(
      (_) {}, // error silencioso — el card simplemente no aparece
      (mom) => state = state.copyWith(
        memberOfMonth: mom as MemberOfMonth?,
      ),
    );
  }

  /// Refresca la lista de unidades desde la API.
  Future<void> refresh() => _loadUnits();

  // ── Categorías ───────────────────────────────────────────────────────────

  /// Carga las categorías de puntuación para el campo local del club.
  ///
  /// El resultado se cachea en el estado. Pasá [forceRefresh] en true para
  /// ignorar el cache y volver a consultar la API.
  Future<void> loadCategories(int localFieldId, {bool forceRefresh = false}) async {
    if (state.categories.isNotEmpty && !forceRefresh) return; // ya cargadas

    state = state.copyWith(isLoadingCategories: true);

    final result = await ref
        .read(getScoringCategoriesUseCaseProvider)
        .call(GetScoringCategoriesParams(localFieldId: localFieldId));

    result.fold(
      (failure) => state = state.copyWith(
        isLoadingCategories: false,
        errorMessage: failure.message,
      ),
      (categories) {
        // Inicializar pendingScores con 0 para cada miembro y categoría
        final updatedScores = _buildInitialScores(state.members, categories);
        state = state.copyWith(
          isLoadingCategories: false,
          categories: categories,
          pendingScores: updatedScores,
        );
      },
    );
  }

  // ── Miembro del Mes ──────────────────────────────────────────────────────

  /// Recarga el miembro del mes para la sección actual.
  Future<void> loadMemberOfMonth(int clubId, int sectionId) async {
    state = state.copyWith(isLoadingMemberOfMonth: true);

    final result = await ref
        .read(getMemberOfMonthUseCaseProvider)
        .call(GetMemberOfMonthParams(clubId: clubId, sectionId: sectionId));

    result.fold(
      (_) => state = state.copyWith(
        isLoadingMemberOfMonth: false,
        clearMemberOfMonth: true,
      ),
      (mom) => state = state.copyWith(
        isLoadingMemberOfMonth: false,
        memberOfMonth: mom,
      ),
    );
  }

  // ── Selección de unidad ──────────────────────────────────────────────────

  /// Selecciona una unidad y carga sus miembros desde la API.
  Future<void> selectUnit(Unit unit) async {
    state = state.copyWith(
      selectedUnit: unit,
      members: unit.members,
      pendingScores: _buildInitialScores(unit.members, state.categories),
      isSavedToday: false,
      clearError: true,
    );

    if (unit.members.isEmpty) {
      await _loadUnitDetail(unit);
    }
  }

  Future<void> _loadUnitDetail(Unit unit) async {
    final ctx = await ref.read(clubContextProvider.future);
    if (ctx == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final result = await ref
        .read(getUnitDetailUseCaseProvider)
        .call(GetUnitDetailParams(clubId: ctx.clubId, unitId: unit.id));

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (detail) {
        state = state.copyWith(
          isLoading: false,
          selectedUnit: detail,
          members: detail.members,
          pendingScores:
              _buildInitialScores(detail.members, state.categories),
          isSavedToday: false,
        );
      },
    );
  }

  // ── Puntos por categoría ─────────────────────────────────────────────────

  /// Ajusta los puntos de un miembro en una categoría específica.
  ///
  /// El valor resultante se clampea entre 0 y [category.maxPoints].
  /// Si la sesión ya fue guardada hoy, no hace nada.
  void adjustCategoryPoints(String memberId, int categoryId, int delta) {
    if (state.isSavedToday) return;

    final memberScores = Map<int, int>.from(
      state.pendingScores[memberId] ?? {},
    );
    final current = memberScores[categoryId] ?? 0;

    // Buscar el maxPoints de la categoría
    final category = state.categories.firstWhere(
      (c) => c.scoringCategoryId == categoryId,
      orElse: () => ScoringCategory(
        scoringCategoryId: categoryId,
        name: '',
        maxPoints: 100,
        originLevel: 'LOCAL_FIELD',
        originId: 0,
      ),
    );

    final updated = (current + delta).clamp(0, category.maxPoints);
    memberScores[categoryId] = updated;

    final newScores = Map<String, Map<int, int>>.from(state.pendingScores);
    newScores[memberId] = memberScores;

    state = state.copyWith(pendingScores: newScores);
  }

  /// Establece el puntaje directo para un miembro en una categoría.
  void setCategoryPoints(String memberId, int categoryId, int value) {
    if (state.isSavedToday) return;

    final category = state.categories.firstWhere(
      (c) => c.scoringCategoryId == categoryId,
      orElse: () => ScoringCategory(
        scoringCategoryId: categoryId,
        name: '',
        maxPoints: 100,
        originLevel: 'LOCAL_FIELD',
        originId: 0,
      ),
    );

    final clamped = value.clamp(0, category.maxPoints);
    final memberScores = Map<int, int>.from(
      state.pendingScores[memberId] ?? {},
    );
    memberScores[categoryId] = clamped;

    final newScores = Map<String, Map<int, int>>.from(state.pendingScores);
    newScores[memberId] = memberScores;

    state = state.copyWith(pendingScores: newScores);
  }

  // ── Guardar sesión ───────────────────────────────────────────────────────

  /// Intenta guardar la sesión de puntos del día vía API.
  ///
  /// Retorna [true] si se guardó exitosamente.
  /// Retorna [false] si la validación falla o hay un error de red.
  ///
  /// Regla atómica: todos con puntos > 0, o todos en 0 (sesión en blanco).
  Future<bool> saveSession() async {
    final pendingScores = state.pendingScores;

    if (pendingScores.isEmpty) return false;

    // Calcular total por miembro
    final totalByMember = {
      for (final entry in pendingScores.entries)
        entry.key: entry.value.values.fold(0, (a, b) => a + b)
    };

    final anyWithPoints = totalByMember.values.any((p) => p > 0);
    final anyWithZero = totalByMember.values.any((p) => p == 0);

    // Mezcla inválida: algunos con puntos y otros sin
    if (anyWithPoints && anyWithZero) return false;

    final ctx = await ref.read(clubContextProvider.future);
    if (ctx == null) return false;

    final unit = state.selectedUnit;
    if (unit == null) return false;

    state = state.copyWith(isSaving: true, clearError: true);

    final now = DateTime.now();
    final week = _isoWeekNumber(now);
    final year = _isoWeekYear(now);

    final useCase = ref.read(createWeeklyRecordUseCaseProvider);
    final failures = <String>[];

    for (final entry in pendingScores.entries) {
      final memberId = entry.key;
      final memberCategoryScores = entry.value;

      // Construir el array de scores para el API
      final scores = memberCategoryScores.entries
          .map((e) => {'category_id': e.key, 'points': e.value})
          .toList();

      // attendance = 1 si tiene algún punto, 0 si todo es 0
      final totalPoints =
          memberCategoryScores.values.fold(0, (a, b) => a + b);
      final attendance = totalPoints > 0 ? 1 : 0;
      // punctuality se usa el mismo valor que attendance por defecto
      final punctuality = attendance;

      try {
        final result = await useCase.call(CreateWeeklyRecordParams(
          clubId: ctx.clubId,
          unitId: unit.id,
          userId: memberId,
          week: week,
          year: year,
          attendance: attendance,
          punctuality: punctuality,
          scores: scores,
        ));

        result.fold(
          (failure) => failures.add(memberId),
          (_) {},
        );
      } catch (_) {
        failures.add(memberId);
      }
    }

    if (failures.isNotEmpty) {
      state = state.copyWith(
        isSaving: false,
        errorMessage:
            'Falló el registro para ${failures.length} miembro${failures.length == 1 ? '' : 's'}',
      );
      return false;
    }

    state = state.copyWith(isSaving: false, isSavedToday: true);
    return true;
  }

  /// Reinicia los puntos pendientes a 0 para todos los miembros y categorías.
  /// También resetea el flag de guardado.
  void resetSession() {
    final resetScores =
        _buildInitialScores(state.members, state.categories);
    state = state.copyWith(
      pendingScores: resetScores,
      isSavedToday: false,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Construye el mapa de puntos pendientes inicializado en 0.
  ///
  /// Si no hay categorías aún, usa un único key 0 como placeholder.
  Map<String, Map<int, int>> _buildInitialScores(
    List<UnitMember> members,
    List<ScoringCategory> categories,
  ) {
    if (categories.isEmpty) {
      return {for (final m in members) m.id: {0: 0}};
    }
    return {
      for (final m in members)
        m.id: {
          for (final c in categories) c.scoringCategoryId: 0,
        },
    };
  }

  /// Calcula el número de semana ISO 8601 para una fecha dada.
  ///
  /// ISO 8601: la semana empieza el lunes, y la semana 1 es la que contiene
  /// el primer jueves del año. Esto coincide con el cálculo del backend.
  int _isoWeekNumber(DateTime date) {
    // Ajustar al jueves de la misma semana ISO
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    final jan1 = DateTime(thursday.year, 1, 1);
    final dayOfYear = thursday.difference(jan1).inDays;
    return (dayOfYear ~/ 7) + 1;
  }

  /// Retorna el año ISO 8601 para una fecha dada.
  ///
  /// Para semanas que cruzan el fin de año (ej. semana 1 de enero que pertenece
  /// al año anterior), el año ISO puede diferir del año calendario.
  int _isoWeekYear(DateTime date) {
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    return thursday.year;
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

/// Provider principal para el feature de unidades.
final unitsNotifierProvider =
    NotifierProvider<UnitsNotifier, UnitsState>(
  UnitsNotifier.new,
);

// ── Member of Month History Provider ──────────────────────────────────────────

/// Estado para el historial paginado del Miembro del Mes.
class MemberOfMonthHistoryState {
  final List<MemberOfMonth> items;
  final int currentPage;
  final int totalItems;
  final bool isLoading;
  final bool hasMore;
  final String? errorMessage;

  const MemberOfMonthHistoryState({
    this.items = const [],
    this.currentPage = 0,
    this.totalItems = 0,
    this.isLoading = false,
    this.hasMore = true,
    this.errorMessage,
  });

  MemberOfMonthHistoryState copyWith({
    List<MemberOfMonth>? items,
    int? currentPage,
    int? totalItems,
    bool? isLoading,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MemberOfMonthHistoryState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalItems: totalItems ?? this.totalItems,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Parámetros para el historial del Miembro del Mes.
class MemberOfMonthHistoryParams {
  final int clubId;
  final int sectionId;

  const MemberOfMonthHistoryParams({
    required this.clubId,
    required this.sectionId,
  });
}

/// Notifier para el historial paginado del Miembro del Mes.
class MemberOfMonthHistoryNotifier
    extends FamilyNotifier<MemberOfMonthHistoryState, MemberOfMonthHistoryParams> {
  static const _pageSize = 12;

  @override
  MemberOfMonthHistoryState build(MemberOfMonthHistoryParams arg) {
    // Cargar la primera página al construir
    Future.microtask(() => fetchNextPage());
    return const MemberOfMonthHistoryState();
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final nextPage = state.currentPage + 1;

    final result = await ref
        .read(getMemberOfMonthHistoryUseCaseProvider)
        .call(GetMemberOfMonthHistoryParams(
          clubId: arg.clubId,
          sectionId: arg.sectionId,
          page: nextPage,
          limit: _pageSize,
        ));

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (response) {
        final rawData = response['data'] as List<dynamic>? ?? [];
        final newItems = rawData
            .whereType<Map<String, dynamic>>()
            .map((json) => MemberOfMonthModel.fromJson(json).toEntity())
            .toList();

        final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
        final total = _parseInt(pagination['total']) ?? 0;
        final totalLoaded = state.items.length + newItems.length;

        state = state.copyWith(
          items: [...state.items, ...newItems],
          currentPage: nextPage,
          totalItems: total,
          isLoading: false,
          hasMore: totalLoaded < total,
        );
      },
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// Provider para el historial del Miembro del Mes.
///
/// Se parametriza con [MemberOfMonthHistoryParams] para soportar múltiples secciones.
final memberOfMonthHistoryProvider = NotifierProvider.family<
    MemberOfMonthHistoryNotifier,
    MemberOfMonthHistoryState,
    MemberOfMonthHistoryParams>(
  MemberOfMonthHistoryNotifier.new,
);
