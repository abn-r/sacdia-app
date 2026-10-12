/// Reading progress of a batch, derived by the backend from the OCR job.
enum CertificateImportOcrState {
  pending,
  running,
  done,
  empty,
  failed;

  /// True once the backend will not change the answer by itself.
  bool get isTerminal => this == done || this == empty || this == failed;

  /// Parses the API value, or returns `null` for anything unknown.
  static CertificateImportOcrState? tryParse(Object? value) {
    for (final state in values) {
      if (state.name == value) return state;
    }
    return null;
  }
}
