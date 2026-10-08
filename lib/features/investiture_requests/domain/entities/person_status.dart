/// Estado de una persona dentro de una solicitud de investidura por
/// autorización (o de su entrada de historial).
///
/// `rejected` es la forma que ve la propia persona: el backend colapsa los dos
/// rechazos en un único estado sin motivo (BC-3). `unknown` evita romper la
/// app ante un estado nuevo que el cliente todavía no conoce.
enum PersonStatus {
  pending,
  invested,
  rejectedByPerson,
  rejectedBySystem,
  rejected,
  removed,
  closedYear,
  unknown;

  static PersonStatus fromString(String? value) {
    switch (value) {
      case 'PENDING':
        return PersonStatus.pending;
      case 'INVESTED':
        return PersonStatus.invested;
      case 'REJECTED_BY_PERSON':
        return PersonStatus.rejectedByPerson;
      case 'REJECTED_BY_SYSTEM':
        return PersonStatus.rejectedBySystem;
      case 'REJECTED':
        return PersonStatus.rejected;
      case 'REMOVED':
        return PersonStatus.removed;
      case 'CLOSED_YEAR':
        return PersonStatus.closedYear;
      default:
        return PersonStatus.unknown;
    }
  }
}
