import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CacheConfigService {
  static const int maxCacheSize = 100 * 1024 * 1024;
  
  static const int cacheStalePeriod = 30;

  static CacheManager? _imageCacheManager;
  
  static Future<CacheManager> getImageCacheManager() async {
    if (_imageCacheManager != null) {
      return _imageCacheManager!;
    }
    
    try {
      final cacheDir = await getTemporaryDirectory();
      
      print('Директория кеша: ${cacheDir.path}');
      
      _imageCacheManager = CacheManager(
        Config(
          'imageCache',
          stalePeriod: Duration(days: cacheStalePeriod),
          maxNrOfCacheObjects: 500,
          repo: JsonCacheInfoRepository(databaseName: 'imageCache.db'),
          fileService: HttpFileService(),
        ),
      );
      
      return _imageCacheManager!;
    } catch (e) {
      print('Ошибка настройки кеша изображений: $e');
      return DefaultCacheManager();
    }
  }

  static Future<int> getCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      
      final cacheSubdirs = [
        '${cacheDir.path}/libCachedImageData',
        '${cacheDir.path}/imageCache',
      ];
      
      int totalSize = 0;
      for (final subdirPath in cacheSubdirs) {
        final subdir = Directory(subdirPath);
        if (await subdir.exists()) {
          await for (final entity in subdir.list(recursive: true)) {
            if (entity is File) {
              try {
                totalSize += await entity.length();
              } catch (e) {
              }
            }
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Ошибка получения размера кеша: $e');
      return 0;
    }
  }

  static Future<void> clearImageCache() async {
    try {
      await DefaultCacheManager().emptyCache();
      
      if (_imageCacheManager != null) {
        await _imageCacheManager!.emptyCache();
      }
      
      print('Кеш изображений очищен');
    } catch (e) {
      print('Ошибка очистки кеша изображений: $e');
    }
  }
  
  static Future<int> getThemeCacheSize() async {
    try {
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static String formatCacheSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes Б';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГБ';
    }
  }
}

