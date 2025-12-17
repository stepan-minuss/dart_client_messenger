import '../services/cache_config_service.dart';

class CacheInfoHelper {
  static Future<String> getCacheSizeFormatted() async {
    final size = await CacheConfigService.getCacheSize();
    return CacheConfigService.formatCacheSize(size);
  }

  static Future<bool> hasCachedData() async {
    final size = await CacheConfigService.getCacheSize();
    return size > 0;
  }
}

