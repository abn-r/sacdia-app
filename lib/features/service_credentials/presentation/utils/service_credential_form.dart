import '../../../../core/consent/consent_evidence.dart';
import 'service_credential_labels.dart';

enum ServiceCredentialDateError { required, future }

/// What is wrong with the upload form, field by field. Empty = can submit.
class ServiceCredentialFormErrors {
  const ServiceCredentialFormErrors({
    this.date,
    this.fileMissing = false,
    this.file,
  });

  final ServiceCredentialDateError? date;
  final bool fileMissing;
  final ServiceCredentialFileProblem? file;

  bool get isEmpty => date == null && !fileMissing && file == null;
}

/// Pure validation of the upload form: the
/// completion date cannot be in the future and the file must be a PDF, JPG or
/// PNG of at most 10 MB. [today] is injected so tests do not depend on the
/// clock.
ServiceCredentialFormErrors validateServiceCredentialForm({
  required DateTime? completedAt,
  required ConsentEvidenceLocalFile? file,
  required DateTime today,
}) {
  ServiceCredentialDateError? date;
  if (completedAt == null) {
    date = ServiceCredentialDateError.required;
  } else {
    final day = DateTime(completedAt.year, completedAt.month, completedAt.day);
    final limit = DateTime(today.year, today.month, today.day);
    if (day.isAfter(limit)) date = ServiceCredentialDateError.future;
  }

  return ServiceCredentialFormErrors(
    date: date,
    fileMissing: file == null,
    file: file == null ? null : serviceCredentialFileProblem(file),
  );
}
