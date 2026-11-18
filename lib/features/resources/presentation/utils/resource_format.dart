import '../../domain/entities/resource.dart';

/// Human readable file size ("840.0 KB"). Empty when [bytes] is unknown.
String formatResourceFileSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Playback clock: `m:ss`, or `h:mm:ss` from one hour on.
String formatResourceDuration(Duration value) {
  final totalSeconds = value.inSeconds < 0 ? 0 : value.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

/// Whether [resource] is a document the in-app PDF viewer can open.
bool resourceIsPdf(Resource resource) {
  if (resource.resourceType != 'document') return false;
  final mime = resource.fileMimeType?.toLowerCase() ?? '';
  final name = resource.fileName?.toLowerCase() ?? '';
  return mime.contains('pdf') || name.endsWith('.pdf');
}
