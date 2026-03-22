import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../data/datasources/units_remote_data_source.dart';
import '../../data/repositories/units_repository_impl.dart';
import '../../domain/entities/unit.dart';
import '../../domain/entities/unit_member.dart';
import '../../domain/repositories/units_repository.dart';
import '../../domain/usecases/add_unit_member.dart';
import '../../domain/usecases/create_unit.dart';
import '../../domain/usecases/create_weekly_record.dart';
import '../../domain/usecases/delete_unit.dart';
import '../../domain/usecases/get_club_units.dart';
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

// ── State ──────────────────────────────────────────────────────────────────────

/// Estado inmutable del feature de unidades.
class UnitsState {
  /// Lista de unidades disponibles para el usuario.
  final List<Unit> units;

  /// Unidad actualmente seleccionada (null = ninguna).
  final Unit? selectedUnit;

  /// Miembros de la unidad seleccionada.
  final List<UnitMember> members;

  /// Puntos pendientes de guardar: memberId → puntos.
  /// Se inicializa con 0 para cada miembro al seleccionar unidad.
  final Map<String, int> pendingPoints;

  /// Si ya se registraron los puntos del día para la unidad activa.
  final bool isSavedToday;

  /// Puntos máximos por sesión por miembro.
  final int maxPoints;

  /// Si se está cargando la lista de unidades o miembros.
  final bool isLoading;

  /// Si se está guardando la sesión de puntos.
  final bool isSaving;

  /// Mensaje de error (null = sin error).
  final String? errorMessage;

  const UnitsState({
    required this.units,
    this.selectedUnit,
    this.members = const [],
    this.pendingPoints = const {},
    this.isSavedToday = false,
    this.maxPoints = 100,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  UnitsState copyWith({
    List<Unit>? units,
    Unit? selectedUnit,
    bool clearSelectedUnit = false,
    List<UnitMember>? members,
    Map<String, int>? pendingPoints,
    bool? isSavedToday,
    int? maxPoints,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UnitsState(
      units: units ?? this.units,
      selectedUnit:
          clearSelectedUnit ? null : (selectedUnit ?? this.selectedUnit),
      members: members ?? this.members,
      pendingPoints: pendingPoints ?? this.pendingPoints,
      isSavedToday: isSavedToday ?? this.isSavedToday,
      maxPoints: maxPoints ?? this.maxPoints,
      isLoading: isLoading ?? this.isLoading,
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

    final result = await ref
        .read(getClubUnitsUseCaseProvider)
        .call(GetClubUnitsParams(clubId: ctx.clubId));

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (units) => state = state.copyWith(
        isLoading: false,
        units: units,
      ),
    );
  }

  /// Refresca la lista de unidades desde la API.
  Future<void> refresh() => _loadUnits();

  // ── Selección de unidad ──────────────────────────────────────────────────

  /// Selecciona una unidad y carga sus miembros desde la API.
  Future<void> selectUnit(Unit unit) async {
    state = state.copyWith(
      selectedUnit: unit,
      members: unit.members,
      pendingPoints: {for (final m in unit.members) m.id: 0},
      isSavedToday: false,
      clearError: true,
    );

    // Si los miembros ya vienen en la entidad (incluidos en la lista),
    // no necesitamos un segundo fetch. Pero si la unidad viene de la lista
    // sin miembros detallados, hacemos el fetch del detalle.
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
        final initialPoints = {for (final m in detail.members) m.id: 0};
        state = state.copyWith(
          isLoading: false,
          selectedUnit: detail,
          members: detail.members,
          pendingPoints: initialPoints,
          isSavedToday: false,
        );
      },
    );
  }

  // ── Puntos ───────────────────────────────────────────────────────────────

  /// Ajusta los puntos de un miembro en [delta] unidades.
  ///
  /// El valor resultante se clampea entre 0 y [state.maxPoints].
  /// Si la sesión ya fue guardada hoy, no hace nada.
  void adjustPoints(String memberId, int delta) {
    if (state.isSavedToday) return;

    final current = state.pendingPoints[memberId] ?? 0;
    final updated = (current + delta).clamp(0, state.maxPoints);

    final newPoints = Map<String, int>.from(state.pendingPoints);
    newPoints[memberId] = updated;

    state = state.copyWith(pendingPoints: newPoints);
  }

  // ── Guardar sesión ───────────────────────────────────────────────────────

  /// Intenta guardar la sesión de puntos del día vía API.
  ///
  /// Retorna [true] si se guardó exitosamente.
  /// Retorna [false] si la validación falla o hay un error de red.
  ///
  /// Regla atómica: todos con puntos > 0, o todos en 0 (sesión en blanco).
  Future<bool> saveSession() async {
    final points = state.pendingPoints;

    if (points.isEmpty) return false;

    final anyWithPoints = points.values.any((p) => p > 0);
    final anyWithZero = points.values.any((p) => p == 0);

    // Mezcla inválida: algunos con puntos y otros sin
    if (anyWithPoints && anyWithZero) return false;

    final ctx = await ref.read(clubContextProvider.future);
    if (ctx == null) return false;

    final unit = state.selectedUnit;
    if (unit == null) return false;

    state = state.copyWith(isSaving: true, clearError: true);

    final now = DateTime.now();
    // ISO 8601 week number — semanas del año (1-52)
    final week = _isoWeekNumber(now);

    final useCase = ref.read(createWeeklyRecordUseCaseProvider);
    bool allOk = true;

    for (final entry in points.entries) {
      final memberId = entry.key;
      final memberPoints = entry.value;

      final result = await useCase.call(CreateWeeklyRecordParams(
        clubId: ctx.clubId,
        unitId: unit.id,
        userId: memberId,
        week: week,
        attendance: memberPoints,
        punctuality: memberPoints,
        points: memberPoints,
      ));

      result.fold(
        (failure) {
          allOk = false;
          state = state.copyWith(
            isSaving: false,
            errorMessage: failure.message,
          );
        },
        (_) {},
      );

      if (!allOk) break;
    }

    if (allOk) {
      state = state.copyWith(isSaving: false, isSavedToday: true);
    }

    return allOk;
  }

  /// Reinicia los puntos pendientes a 0 para todos los miembros.
  /// También resetea el flag de guardado.
  void resetSession() {
    final resetPoints = {for (final m in state.members) m.id: 0};
    state = state.copyWith(
      pendingPoints: resetPoints,
      isSavedToday: false,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Calcula el número de semana ISO 8601 para una fecha dada.
  int _isoWeekNumber(DateTime date) {
    final dayOfYear = int.parse(
      '${date.difference(DateTime(date.year, 1, 1)).inDays + 1}',
    );
    // Aproximación: semana del año (1-52)
    return ((dayOfYear - 1) ~/ 7) + 1;
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

/// Provider principal para el feature de unidades.
final unitsNotifierProvider =
    NotifierProvider<UnitsNotifier, UnitsState>(
  UnitsNotifier.new,
);
