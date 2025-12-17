import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageCacheConfig {
  static const int avatarCacheWidth = 200;
  static const int avatarCacheHeight = 200;
  
  static const int messageMediaCacheWidth = 800;
  static const int messageMediaCacheHeight = 800;
  
  static const int wallpaperCacheWidth = 1200;
  static const int wallpaperCacheHeight = 1200;
  
  static CachedNetworkImage avatarImage({
    required String imageUrl,
    required double size,
    BoxFit fit = BoxFit.cover,
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: fit,
      memCacheWidth: avatarCacheWidth,
      memCacheHeight: avatarCacheHeight,
      maxWidthDiskCache: avatarCacheWidth,
      maxHeightDiskCache: avatarCacheHeight,
      cacheKey: 'avatar_$imageUrl',
      placeholder: placeholder ??
          (context, url) => const SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
      errorWidget: errorWidget ??
          (context, url, error) => Container(
              color: const Color(0xFF1A1A1A),
              child: const Icon(Icons.person, color: Colors.grey),
            ),
    );
  }
  
  static CachedNetworkImage messageMediaImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: messageMediaCacheWidth,
      memCacheHeight: messageMediaCacheHeight,
      maxWidthDiskCache: messageMediaCacheWidth,
      maxHeightDiskCache: messageMediaCacheHeight,
      cacheKey: 'message_media_$imageUrl',
      placeholder: placeholder ??
          (context, url) => Container(
              color: const Color(0xFF1A1A1A),
              child: const Center(child: CircularProgressIndicator()),
            ),
      errorWidget: errorWidget ??
          (context, url, error) => Container(
              color: const Color(0xFF1A1A1A),
              child: const Icon(Icons.error, color: Colors.red),
            ),
    );
  }
  
  static CachedNetworkImage wallpaperImage({
    required String imageUrl,
    BoxFit fit = BoxFit.cover,
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: wallpaperCacheWidth,
      memCacheHeight: wallpaperCacheHeight,
      maxWidthDiskCache: wallpaperCacheWidth,
      maxHeightDiskCache: wallpaperCacheHeight,
      cacheKey: 'wallpaper_$imageUrl',
      placeholder: placeholder ??
          (context, url) => Container(
              color: const Color(0xFF1A1A1A),
            ),
      errorWidget: errorWidget ??
          (context, url, error) => Container(
              color: const Color(0xFF1A1A1A),
            ),
    );
  }
  
  static CachedNetworkImageProvider avatarImageProvider(String imageUrl) {
    return CachedNetworkImageProvider(
      imageUrl,
      cacheKey: 'avatar_$imageUrl',
      maxWidth: avatarCacheWidth,
      maxHeight: avatarCacheHeight,
    );
  }
}

