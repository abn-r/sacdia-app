/// Helpers to tell what an evidence URL points to.
///
/// Evidence URLs are presigned R2 links
/// (`https://host/key.pdf?X-Amz-Signature=...`), so the type must be read from
/// the path, never from the end of the whole string: the query hides the
/// extension.
library;

/// True when [url] points to a PDF: a `.pdf` path (query and fragment
/// ignored) or a `/pdf` segment.
bool isPdfEvidenceUrl(String url) {
  final trimmed = url.trim();
  final path =
      Uri.tryParse(trimmed)?.path.toLowerCase() ?? trimmed.toLowerCase();
  return path.endsWith('.pdf') || trimmed.toLowerCase().contains('/pdf');
}

/// True when [url] can be fetched as it is: an http(s) link.
///
/// A raw storage key (`batches/<id>/sealed/<id>.pdf`) means the API failed to
/// sign it, so there is nothing the app can download.
bool isFetchableEvidenceUrl(String url) {
  final scheme = Uri.tryParse(url.trim())?.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}
