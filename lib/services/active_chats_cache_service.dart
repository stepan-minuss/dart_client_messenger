import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';

class ActiveChatsCacheService {
  static const String _cacheKey = 'active_chats_cache';
  static const String _lastUpdateKey = 'active_chats_last_update';
  static const int _maxCacheAgeHours = 24;

  Future<void> cacheActiveChats(List<User> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = users.map((user) => {
        'id': user.id,
        'username': user.username,
        'first_name': user.firstName,
        'last_name': user.lastName,
        'phone': user.phone,
        'public_key': user.publicKey,
        'avatar_url': user.avatarUrl,
        'avatar_frame': user.avatarFrame,
        'bio': user.bio,
        'birthdate': user.birthdate,
        'last_seen': user.lastSeen != null 
            ? user.lastSeen!.toUtc().toIso8601String()
            : null,
        'is_online': user.isOnline,
        'last_message': user.lastMessage,
        'last_message_time': user.lastMessageTime != null 
            ? user.lastMessageTime!.toUtc().toIso8601String()
            : null,
        'last_message_sender_id': user.lastMessageSenderId,
        'last_message_type': user.lastMessageType,
        'local_name': user.localName,
      }).toList();
      await prefs.setString(_cacheKey, jsonEncode(usersJson));
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());

      print('Кешировано ${users.length} активных чатов');
    } catch (e) {
      print('Ошибка кеширования активных чатов: $e');
    }
  }

  Future<List<User>?> getCachedActiveChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey);
      if (cacheData == null) {
        return null;
      }
      final lastUpdateStr = prefs.getString(_lastUpdateKey);
      if (lastUpdateStr != null) {
        final lastUpdate = DateTime.parse(lastUpdateStr);
        final age = DateTime.now().difference(lastUpdate);
        if (age.inHours > _maxCacheAgeHours) {
          await prefs.remove(_cacheKey);
          await prefs.remove(_lastUpdateKey);
          print('Удален устаревший кеш активных чатов (${age.inHours} часов)');
          return null;
        }
      }
      final List<dynamic> usersJson = jsonDecode(cacheData);
      
      final users = <User>[];
      for (final json in usersJson) {
        try {
          users.add(User(
            id: json['id'] as int,
            username: json['username'] as String,
            firstName: json['first_name'] as String?,
            lastName: json['last_name'] as String?,
            phone: json['phone'] as String?,
            publicKey: json['public_key'] as String?,
            avatarUrl: json['avatar_url'] as String?,
            avatarFrame: json['avatar_frame'] as String?,
            bio: json['bio'] as String?,
            birthdate: json['birthdate'] as String?,
            lastSeen: json['last_seen'] != null 
                ? (() {
                    final dateStr = json['last_seen'] as String;
                    DateTime? parsed = DateTime.tryParse(dateStr);
                    if (parsed != null) {
                      if (!parsed.isUtc && !dateStr.endsWith('Z') && !dateStr.contains('+') && !dateStr.contains('-', 10)) {
                        parsed = DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second, parsed.millisecond);
                      }
                      return parsed.toLocal();
                    }
                    return null;
                  })()
                : null,
            isOnline: json['is_online'] as bool?,
            lastMessage: json['last_message'] as String?,
            lastMessageTime: json['last_message_time'] != null
                ? (() {
                    final dateStr = json['last_message_time'] as String;
                    DateTime? parsed = DateTime.tryParse(dateStr);
                    if (parsed != null) {
                      if (!parsed.isUtc && !dateStr.endsWith('Z') && !dateStr.contains('+') && !dateStr.contains('-', 10)) {
                        parsed = DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second, parsed.millisecond);
                      }
                      return parsed.toLocal();
                    }
                    return null;
                  })()
                : null,
            lastMessageSenderId: json['last_message_sender_id'] as int?,
            lastMessageType: json['last_message_type'] as String?,
            localName: json['local_name'] as String?,
          ));
        } catch (e) {
          print('Ошибка парсинга чата из кеша: $e, json: $json');
        }
      }

      print('Загружено ${users.length} активных чатов из кеша');
      return users;
    } catch (e) {
      print('Ошибка загрузки активных чатов из кеша: $e');
      return null;
    }
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_lastUpdateKey);
      print('Кеш активных чатов очищен');
    } catch (e) {
      print('Ошибка очистки кеша активных чатов: $e');
    }
  }
}

