import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// App-wide image cache manager.
///
/// Overrides the [DefaultCacheManager] defaults to match SACDIA's catalog size:
/// - maxNrOfCacheObjects: 500  (honors catalog alone can exceed 200 badges)
/// - stalePeriod: 30 days      (honor badge images rarely change)
///
/// Usage: pass [SacCacheManager.instance] as the `cacheManager` parameter
/// to any [CachedNetworkImage] that needs non-default caching behavior,
/// or use it directly when pre-caching assets.
///
/// For the majority of call sites that do not specify a cacheManager,
/// [CachedNetworkImage] falls back to [DefaultCacheManager] (200 objects /
/// 30 days). Only high-volume screens (honors catalog, profile honors grid)
/// benefit from this larger instance.
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
