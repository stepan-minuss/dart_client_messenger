import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme.dart';

class ThemeService extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.cyberViolet;
  static const String _themeKey = 'custom_theme_data';
  static const String _themeVersionKey = 'custom_theme_version';
  static const String _themeCacheTimestampKey = 'custom_theme_cache_timestamp';
  
  static const int _currentThemeVersion = 1;
  
  bool _isThemeLoaded = false;

  AppTheme get currentTheme => _currentTheme;
  bool get isThemeLoaded => _isThemeLoaded;

  ThemeService() {
    _loadThemeSync();
    _loadTheme();
  }

  void _loadThemeSync() {
    try {
      _currentTheme = AppTheme.cyberViolet;
      _isThemeLoaded = true;
    } catch (e) {
      print('Ошибка синхронной загрузки темы: $e');
      _currentTheme = AppTheme.cyberViolet;
      _isThemeLoaded = true;
    }
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeJson = prefs.getString(_themeKey);
      final cachedVersion = prefs.getInt(_themeVersionKey) ?? 0;
      
      if (themeJson != null && cachedVersion == _currentThemeVersion) {
        try {
          final Map<String, dynamic> json = jsonDecode(themeJson);
          final loadedTheme = AppTheme.fromJson(json);
          
          _currentTheme = loadedTheme;
          _isThemeLoaded = true;
          notifyListeners();
          print('Тема загружена из кеша: ${loadedTheme.name}');
        } catch (e) {
          print('Ошибка парсинга темы из кеша: $e');
          _currentTheme = AppTheme.cyberViolet;
          _isThemeLoaded = true;
          notifyListeners();
        }
      } else {
        if (cachedVersion != _currentThemeVersion) {
          print('Версия кеша темы устарела, используем тему по умолчанию');
        }
        _isThemeLoaded = true;
        notifyListeners();
      }
    } catch (e) {
      print('Ошибка загрузки темы: $e');
      _currentTheme = AppTheme.cyberViolet;
      _isThemeLoaded = true;
      notifyListeners();
    }
  }
  
  Future<bool> hasCachedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeJson = prefs.getString(_themeKey);
      final cachedVersion = prefs.getInt(_themeVersionKey) ?? 0;
      return themeJson != null && cachedVersion == _currentThemeVersion;
    } catch (e) {
      return false;
    }
  }
  
  Future<DateTime?> getThemeCacheTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_themeCacheTimestampKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    _isThemeLoaded = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(theme.toJson());
      
      await prefs.setString(_themeKey, jsonString);
      await prefs.setInt(_themeVersionKey, _currentThemeVersion);
      await prefs.setInt(_themeCacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      
      print('Тема сохранена в кеш: ${theme.name}');
    } catch (e) {
      print('Ошибка сохранения темы в кеш: $e');
    }
  }
  
  Future<void> clearThemeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_themeKey);
      await prefs.remove(_themeVersionKey);
      await prefs.remove(_themeCacheTimestampKey);
      
      _currentTheme = AppTheme.cyberViolet;
      notifyListeners();
      print('Кеш темы очищен');
    } catch (e) {
      print('Ошибка очистки кеша темы: $e');
    }
  }
  
  Future<int> getThemeCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeJson = prefs.getString(_themeKey);
      if (themeJson != null) {
        return themeJson.length * 2;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> updateColors({
    Color? primaryColor,
    Color? backgroundColor,
    Color? bubbleColorMe,
    Color? bubbleColorOther,
    Color? textColor,
    Color? secondaryTextColor,
  }) async {
    final newTheme = _currentTheme.copyWith(
      name: 'Custom',
      primaryColor: primaryColor,
      backgroundColor: backgroundColor,
      bubbleColorMe: bubbleColorMe,
      bubbleColorOther: bubbleColorOther,
      textColor: textColor,
      secondaryTextColor: secondaryTextColor,
    );
    await setTheme(newTheme);
  }

  Future<void> resetToDefault() async {
    await setTheme(AppTheme.cyberViolet);
  }

  Future<void> toggleTheme() async {
    if (_currentTheme.brightness == Brightness.light) {
      await setTheme(AppTheme.cyberViolet);
    } else {
      await setTheme(AppTheme.light);
    }
  }
}
