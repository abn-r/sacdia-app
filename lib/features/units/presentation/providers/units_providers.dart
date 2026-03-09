import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/unit.dart';
import '../../domain/entities/unit_member.dart';

// ── Mock data ─────────────────────────────────────────────────────────────────

/// Unidades de ejemplo — se reemplazará con datos reales de la API.
final _mockUnits = [
  const Unit(
    id: 1,
    name: 'Unidad Alpha',
    type: 'Conquistadores',
    memberCount: 8,
    leaderName: 'Juan Pérez',
  ),
  const Unit(
    id: 2,
    name: 'Unidad Beta',
    type: 'Aventureros',
    memberCount: 6,
    leaderName: 'María López',
  ),
];

/// Miembros de ejemplo — se reemplazará con datos reales de la API.
final _mockMembers = [
  const UnitMember(id: '1', name: 'Carlos', surname: 'Rodríguez'),
  const UnitMember(id: '2', name: 'Ana', surname: 'García'),
  const UnitMember(id: '3', name: 'Luis', surname: 'Martínez'),
  const UnitMember(id: '4', name: 'Sofía', surname: 'López'),
  const UnitMember(id: '5', name: 'Diego', surname: 'Hernández'),
];

// ── State ─────────────────────────────────────────────────────────────────────

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

  const UnitsState({
    required this.units,
    this.selectedUnit,
    this.members = const [],
    this.pendingPoints = const {},
    this.isSavedToday = false,
    this.maxPoints = 100,
  });

  UnitsState copyWith({
    List<Unit>? units,
    Unit? selectedUnit,
    bool clearSelectedUnit = false,
    List<UnitMember>? members,
    Map<String, int>? pendingPoints,
    bool? isSavedToday,
    int? maxPoints,
  }) {
    return UnitsState(
      units: units ?? this.units,
      selectedUnit:
          clearSelectedUnit ? null : (selectedUnit ?? this.selectedUnit),
      members: members ?? this.members,
      pendingPoints: pendingPoints ?? this.pendingPoints,
      isSavedToday: isSavedToday ?? this.isSavedToday,
      maxPoints: maxPoints ?? this.maxPoints,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Gestiona el estado del feature de unidades.
///
/// Usa mock data hasta que se integre la API real.
class UnitsNotifier extends StateNotifier<UnitsState> {
  UnitsNotifier()
      : super(UnitsState(
          units: _mockUnits,
        ));

  /// Selecciona una unidad y carga sus miembros con puntos iniciales en 0.
  void selectUnit(Unit unit) {
    final initialPoints = {for (final m in _mockMembers) m.id: 0};
    state = state.copyWith(
      selectedUnit: unit,
      members: _mockMembers,
      pendingPoints: initialPoints,
      isSavedToday: false,
    );
  }

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

  /// Intenta guardar la sesión de puntos del día.
  ///
  /// Retorna [true] si se guardó exitosamente.
  /// Retorna [false] si la validación falla:
  ///   - Al menos un miembro tiene puntos > 0 y al menos uno tiene 0.
  ///
  /// Regla: todos con puntos > 0, o todos en 0 (sesión en blanco).
  bool saveSession() {
    final points = state.pendingPoints;

    if (points.isEmpty) return false;

    final anyWithPoints = points.values.any((p) => p > 0);
    final anyWithZero = points.values.any((p) => p == 0);

    // Mezcla inválida: algunos con puntos y otros sin
    if (anyWithPoints && anyWithZero) return false;

    // Sesión válida (todos > 0 o todos == 0)
    state = state.copyWith(isSavedToday: true);
    return true;
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
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Provider principal para el feature de unidades.
final unitsNotifierProvider =
    StateNotifierProvider<UnitsNotifier, UnitsState>((ref) {
  return UnitsNotifier();
});
