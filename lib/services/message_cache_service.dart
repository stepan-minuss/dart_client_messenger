import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/socket_service.dart';

class MessageCacheService {
  static const String _cachePrefix = 'message_cache_';
  static const String _lastUpdatePrefix = 'last_update_';
  static const int _maxCacheAgeDays = 7;

  Future<void> cacheMessages(int chatUserId, List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$chatUserId';
      final lastUpdateKey = '$_lastUpdatePrefix$chatUserId';

      final validMessages = messages.where((msg) => msg.id < 1000000000000).toList();
      
      final messagesJson = validMessages.map((msg) => {
        'id': msg.id,
        'sender_id': msg.senderId,
        'receiver_id': msg.receiverId,
        'encrypted_content': msg.encryptedContent,
        'message_type': msg.messageType,
        'media_url': msg.mediaUrl,
        'timestamp': msg.timestamp.toIso8601String(),
        'is_read': msg.isRead,
        'reply_to_message_id': msg.replyToMessageId,
        'reply_to_text': msg.replyToText,
        'reply_to_sender_name': msg.replyToSenderName,
      }).toList();

      final jsonString = jsonEncode(messagesJson);
      await prefs.setString(cacheKey, jsonString);
      await prefs.setString(lastUpdateKey, DateTime.now().toIso8601String());

      final saved = prefs.getString(cacheKey);
      if (saved != null) {
        print('Кешировано ${validMessages.length} сообщений для чата $chatUserId (размер: ${saved.length} байт, отфильтровано временных: ${messages.length - validMessages.length})');
      } else {
        print('ОШИБКА: Сообщения не сохранились в кеш для чата $chatUserId');
      }
    } catch (e) {
      print('Ошибка кеширования сообщений: $e');
    }
  }

  Future<List<ChatMessage>?> getCachedMessages(int chatUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$chatUserId';
      final lastUpdateKey = '$_lastUpdatePrefix$chatUserId';

      final cacheData = prefs.getString(cacheKey);
      if (cacheData == null) {
        return null;
      }

      final lastUpdateStr = prefs.getString(lastUpdateKey);
      if (lastUpdateStr != null) {
        final lastUpdate = DateTime.parse(lastUpdateStr);
        final age = DateTime.now().difference(lastUpdate);
        if (age.inDays > _maxCacheAgeDays) {
          await prefs.remove(cacheKey);
          await prefs.remove(lastUpdateKey);
          print('Удален устаревший кеш для чата $chatUserId (${age.inDays} дней)');
          return null;
        }
      }

      final List<dynamic> messagesJson = jsonDecode(cacheData);
      
      final messages = <ChatMessage>[];
      
      for (final json in messagesJson) {
        try {
          final timestampStr = json['timestamp'] as String;
          DateTime timestamp = DateTime.parse(timestampStr);
          if (timestamp.isUtc) {
            timestamp = timestamp.toLocal();
          }
          
          messages.add(ChatMessage(
            id: json['id'] as int,
            senderId: json['sender_id'] as int,
            receiverId: json['receiver_id'] as int,
            encryptedContent: json['encrypted_content'] as String,
            messageType: json['message_type'] as String? ?? 'text',
            mediaUrl: json['media_url'] as String?,
            timestamp: timestamp,
            isRead: json['is_read'] as bool? ?? false,
            replyToMessageId: json['reply_to_message_id'] as int?,
            replyToText: json['reply_to_text'] as String?,
            replyToSenderName: json['reply_to_sender_name'] as String?,
          ));
        } catch (e) {
          print('Ошибка парсинга сообщения из кеша: $e, json: $json');
        }
      }

      print('Загружено ${messages.length} сообщений из кеша для чата $chatUserId');
      return messages;
    } catch (e) {
      print('Ошибка загрузки из кеша: $e');
      return null;
    }
  }

  Future<void> addMessageToCache(int chatUserId, ChatMessage message) async {
    try {
      if (message.id >= 1000000000000) {
        print('Пропущено временное сообщение (ID: ${message.id}) - не сохраняется в кеш');
        return;
      }
      
      final cached = await getCachedMessages(chatUserId);
      if (cached != null) {
        if (cached.any((m) => m.id == message.id)) {
          final index = cached.indexWhere((m) => m.id == message.id);
          if (index != -1) {
            cached[index] = message;
          }
        } else {
          cached.add(message);
        }
        cached.sort((a, b) {
          final timeCompare = a.timestamp.compareTo(b.timestamp);
          if (timeCompare != 0) return timeCompare;
          return a.id.compareTo(b.id);
        });
        await cacheMessages(chatUserId, cached);
      } else {
        await cacheMessages(chatUserId, [message]);
      }
    } catch (e) {
      print('Ошибка добавления сообщения в кеш: $e');
    }
  }

  Future<void> updateMessageInCache(int chatUserId, ChatMessage message) async {
    try {
      final cached = await getCachedMessages(chatUserId);
      if (cached != null) {
        final index = cached.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          cached[index] = message;
          await cacheMessages(chatUserId, cached);
        }
      }
    } catch (e) {
      print('Ошибка обновления сообщения в кеше: $e');
    }
  }

  Future<void> removeMessageFromCache(int chatUserId, int messageId) async {
    try {
      final cached = await getCachedMessages(chatUserId);
      if (cached != null) {
        cached.removeWhere((m) => m.id == messageId);
        await cacheMessages(chatUserId, cached);
      }
    } catch (e) {
      print('Ошибка удаления сообщения из кеша: $e');
    }
  }

  Future<void> clearCache(int chatUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$chatUserId';
      final lastUpdateKey = '$_lastUpdatePrefix$chatUserId';
      await prefs.remove(cacheKey);
      await prefs.remove(lastUpdateKey);
      print('Кеш очищен для чата $chatUserId');
    } catch (e) {
      print('Ошибка очистки кеша: $e');
    }
  }

  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_cachePrefix) || key.startsWith(_lastUpdatePrefix)) {
          await prefs.remove(key);
        }
      }
      print('Весь кеш очищен');
    } catch (e) {
      print('Ошибка очистки всего кеша: $e');
    }
  }
}

