import '../../domain/entities/resource.dart';

/// Whether the tile should fetch a signed URL to render a real preview.
bool resourceWantsSignedPreview(Resource resource) {
  if (resource.signedUrl != null && resource.signedUrl!.isNotEmpty) {
    return false;
  }
  if (resource.resourceType == 'image') return true;
  final mime = resource.fileMimeType?.toLowerCase() ?? '';
  return mime.startsWith('image/');
}

/// YouTube poster URL from [externalUrl], or null if it is not a YouTube link.
String? videoPreviewUrl(String? externalUrl) {
  if (externalUrl == null) return null;
  final raw = externalUrl.trim();
  if (raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty) return null;

  final host = uri.host.toLowerCase();
  String? id;

  if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
    if (uri.pathSegments.isNotEmpty) {
      id = uri.pathSegments.first;
    }
  } else if (host.contains('youtube.com') ||
      host.contains('youtube-nocookie.com')) {
    id = uri.queryParameters['v'];
    if (id == null || id.isEmpty) {
      final segs = uri.pathSegments;
      for (final marker in ['embed', 'shorts', 'live', 'v']) {
        final index = segs.indexOf(marker);
        if (index >= 0 && index + 1 < segs.length) {
          id = segs[index + 1];
          break;
        }
      }
    }
  }

  if (id == null || id.isEmpty) return null;
  final clean = id.split('?').first.split('&').first;
  if (clean.isEmpty) return null;
  return 'https://img.youtube.com/vi/$clean/hqdefault.jpg';
}
