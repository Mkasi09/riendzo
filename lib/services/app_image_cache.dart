import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared on-disk cache for remote images used throughout the app.
class AppImageCache {
  AppImageCache._();

  static final CacheManager instance = CacheManager(
    Config(
      'riendzoImageCache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
    ),
  );
}

/// Separate disk cache for videos so large files do not crowd out images.
class AppVideoCache {
  AppVideoCache._();

  static final CacheManager instance = CacheManager(
    Config(
      'riendzoVideoCache',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 30,
    ),
  );
}
