import '../../domain/entities/own_investiture_entry.dart';
import '../../domain/entities/person_status.dart';

/// ¿La entrada trae algo que la persona deba ver?
///
/// `removed` solo aparece cuando el backend manda un texto para la persona
/// (p. ej. un certificado histórico que ya acredita la clase). Un estado que el
/// cliente no conoce no se pinta.
bool ownEntryHasContent(OwnInvestitureEntry entry) {
  switch (entry.status) {
    case PersonStatus.pending:
    case PersonStatus.invested:
    case PersonStatus.rejected:
    case PersonStatus.rejectedByPerson:
    case PersonStatus.rejectedBySystem:
    case PersonStatus.closedYear:
      return true;
    case PersonStatus.removed:
      return entry.personText?.trim().isNotEmpty ?? false;
    case PersonStatus.unknown:
      return false;
  }
}

int _statusRank(PersonStatus status) {
  switch (status) {
    case PersonStatus.pending:
      return 0;
    case PersonStatus.invested:
      return 1;
    default:
      return 2;
  }
}

/// Entrada que representa a la persona en [classId]: la del año más reciente;
/// en el mismo año, la de fecha más tardía; con fecha igual, pendiente antes
/// que investida antes que el resto. `null` si no hay nada que mostrar.
OwnInvestitureEntry? selectOwnEntryForClass(
  Iterable<OwnInvestitureEntry> entries,
  int classId,
) {
  OwnInvestitureEntry? best;
  for (final entry in entries) {
    if (entry.classId != classId || !ownEntryHasContent(entry)) continue;
    if (best == null || _isBetter(entry, best)) best = entry;
  }
  return best;
}

bool _isBetter(OwnInvestitureEntry a, OwnInvestitureEntry b) {
  if (a.ecclesiasticalYearId != b.ecclesiasticalYearId) {
    return a.ecclesiasticalYearId > b.ecclesiasticalYearId;
  }
  final byDate = a.investitureDate.compareTo(b.investitureDate);
  if (byDate != 0) return byDate > 0;
  return _statusRank(a.status) < _statusRank(b.status);
}

/// Historial propio ordenado para listarlo: año reciente primero, luego fecha.
List<OwnInvestitureEntry> sortOwnEntries(
  Iterable<OwnInvestitureEntry> entries,
) {
  final visible = entries.where(ownEntryHasContent).toList();
  visible.sort((a, b) {
    if (a.ecclesiasticalYearId != b.ecclesiasticalYearId) {
      return b.ecclesiasticalYearId.compareTo(a.ecclesiasticalYearId);
    }
    final byDate = b.investitureDate.compareTo(a.investitureDate);
    if (byDate != 0) return byDate;
    return _statusRank(a.status).compareTo(_statusRank(b.status));
  });
  return visible;
}
