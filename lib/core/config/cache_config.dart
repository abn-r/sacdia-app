import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk key for a network image.
///
/// Drops the query and fragment so a signed URL (a new signature every few
/// minutes) hits the same file. A new object path, such as
/// `photo-{userId}-{timestamp}`, is a new key and downloads immediately.
/// When the URL has no query or fragment, the original string is returned so
/// it still matches an [ImageProvider] keyed by that URL.
String stableImageCacheKey(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || (!uri.hasQuery && !uri.hasFragment)) {
    return url;
  }
  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo.isEmpty ? null : uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
}

/// Catalog images (honor badges, class art).
///
/// Installed as [CachedNetworkImageProvider.defaultCacheManager] in `main`.
/// Unused files are removed after 30 days. The store holds 500 objects so the
/// honors catalog does not evict itself.
///
/// Profile photos do not use this store. Their signed URL changes every few
/// minutes and would fill these 500 slots. See [SacProfileCacheManager].
class SacCacheManager extends CacheManager with ImageCacheManager {
  static const _key = 'sacCacheManager';

  static final SacCacheManager instance = SacCacheManager._();

  SacCacheManager._()
      : super(
          Config(
            _key,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 500,
          ),
        );
}

/// Profile photos.
///
/// Separate from [SacCacheManager] so avatar signatures do not evict badges.
/// Unused files are removed after 1 day. Call sites must pass
/// [stableImageCacheKey]: the signature is not part of the key, and a replaced
/// photo (new object name) downloads at once.
class SacProfileCacheManager extends CacheManager with ImageCacheManager {
  static const _key = 'sacProfileCache';

  static final SacProfileCacheManager instance = SacProfileCacheManager._();

  SacProfileCacheManager._()
      : super(
          Config(
            _key,
            stalePeriod: const Duration(days: 1),
            maxNrOfCacheObjects: 200,
          ),
        );
}
