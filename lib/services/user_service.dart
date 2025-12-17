import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class User {
  final int id;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? publicKey;
  final String? avatarUrl;
  final String? avatarFrame;
  final String? bio;
  final String? birthdate;
  final String? phone;
  final DateTime? lastSeen;
  final bool? isOnline;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int? lastMessageSenderId;
  final String? lastMessageType;
  final String? localName;

  User({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.publicKey,
    this.avatarUrl,
    this.avatarFrame,
    this.bio,
    this.birthdate,
    this.phone,
    this.lastSeen,
    this.isOnline,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.lastMessageType,
    this.localName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: json['id'] as int? ?? 0,
        username: (json['username'] as String?) ?? '',
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        publicKey: json['public_key'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        avatarFrame: json['avatar_frame'] as String?,
        bio: json['bio'] as String?,
        birthdate: json['birthdate'] as String?,
        phone: json['phone'] as String?,
        lastSeen: json['last_seen'] != null 
            ? (() {
                if (json['last_seen'] is String) {
                  final dateStr = json['last_seen'] as String;
                  DateTime? parsed = DateTime.tryParse(dateStr);
                  if (parsed != null) {
                    if (parsed.isUtc || dateStr.endsWith('Z') || dateStr.contains('+00:00')) {
                      return parsed.toLocal();
                    }
                    if (!dateStr.contains('+') && !dateStr.contains('-', 10)) {
                      parsed = DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second, parsed.millisecond);
                      return parsed.toLocal();
                    }
                    return parsed.toLocal();
                  }
                  return null;
                }
                return null;
              })()
            : null,
        isOnline: json['is_online'] as bool?,
        lastMessage: json['last_message'] as String?,
        lastMessageTime: json['last_message_time'] != null 
            ? (() {
                if (json['last_message_time'] is String) {
                  final dateStr = json['last_message_time'] as String;
                  DateTime? parsed = DateTime.tryParse(dateStr);
                  if (parsed != null) {
                    if (parsed.isUtc || dateStr.endsWith('Z') || dateStr.contains('+00:00')) {
                      return parsed.toLocal();
                    }
                    if (!dateStr.contains('+') && !dateStr.contains('-', 10)) {
                      parsed = DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second, parsed.millisecond);
                      return parsed.toLocal();
                    }
                    return parsed.toLocal();
                  }
                  return null;
                }
                return null;
              })()
            : null,
        lastMessageSenderId: json['last_message_sender_id'] as int?,
        lastMessageType: json['last_message_type'] as String?,
        localName: json['local_name'] as String?,
      );
    } catch (e) {
      print('Error parsing User from JSON: $e');
      print('JSON: $json');
      rethrow;
    }
  }
}

class UserService {
  final _authService = AuthService();
  final _client = http.Client();

  Future<User> getMe() async {
    try {
      final token = await _authService.getToken();
      print('Токен для /me: ${token != null ? "присутствует (${token.length} символов)" : "отсутствует"}');
      
      if (token == null) {
        throw Exception('Токен авторизации отсутствует. Пожалуйста, войдите снова.');
      }
      
      final headers = await _authService.getAuthHeaders();
      print('Запрос к ${AppConstants.baseUrl}/me');
      print('Заголовки: ${headers.keys.join(", ")}');
      
      final response = await _client.get(
        Uri.parse('${AppConstants.baseUrl}/me'),
        headers: headers,
      );

      print('Ответ сервера: статус ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 401) {
        print('Ошибка 401: Токен недействителен или истек');
        await _authService.handle401Error();
        throw Exception('Сессия истекла. Пожалуйста, войдите снова.');
      } else {
        print('Ошибка ${response.statusCode}: ${response.body}');
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Исключение при загрузке профиля: $e');
      throw Exception('Error loading profile: $e');
    }
  }

  Future<List<User>> getUsers() async {
    try {
      final headers = await _authService.getAuthHeaders();
      print('Запрос списка пользователей: ${AppConstants.baseUrl}${AppConstants.endpointUsers}');
      
      final response = await _client.get(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.endpointUsers}'),
        headers: headers,
      );

      print('Ответ списка пользователей: статус ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final users = data.map((json) {
          print('Пользователь: id=${json['id']}, username=${json['username']}, phone=${json['phone']}');
          return User.fromJson(json);
        }).toList();
        
        final phonesCount = users.where((u) => u.phone != null && u.phone!.isNotEmpty).length;
        print('Получено пользователей: ${users.length}, из них с номерами: $phonesCount');
        
        return users;
      } else {
        print('Ошибка загрузки пользователей: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      print('Исключение при загрузке пользователей: $e');
      throw Exception('Error loading users: $e');
    }
  }

  Future<List<User>> searchUsers(String query) async {
    if (query.length < 2) return [];
    
    try {
      final headers = await _authService.getAuthHeaders();
      final encodedQuery = Uri.encodeComponent(query);
      print('Поиск пользователей: "$query" (закодировано: "$encodedQuery")');
      
      final response = await _client.get(
        Uri.parse('${AppConstants.baseUrl}/users/search?query=$encodedQuery'),
        headers: headers,
      );
      
      print('Ответ поиска: статус ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        try {
          return data.map((json) {
            if (json['id'] == null) {
              print('Warning: User without id in search results');
              return null;
            }
            return User.fromJson(json);
          }).where((user) => user != null).cast<User>().toList();
        } catch (e) {
          print('Error parsing search results: $e');
          print('Response body: ${response.body}');
          return [];
        }
      } else {
        print('Search failed with status ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.get(
        Uri.parse('${AppConstants.baseUrl}/users/check_availability?username=$username'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['available'] as bool;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> updateProfile({String? bio, String? birthdate}) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final queryParams = <String, String>{};
      if (bio != null) {
        queryParams['bio'] = bio;
      }
      if (birthdate != null) {
        queryParams['birthdate'] = birthdate;
      }
      
      final uri = Uri.parse('${AppConstants.baseUrl}/users/me/profile').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      
      print('Обновление профиля: $uri');
      print('Параметры: bio=$bio, birthdate=$birthdate');
      
      final response = await _client.put(
        uri,
        headers: headers,
      );

      print('Ответ сервера: ${response.statusCode}');
      print('Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        print('Профиль обновлен: $userData');
        return {'success': true, 'user': User.fromJson(userData)};
      } else {
        final error = jsonDecode(response.body);
        print('Ошибка обновления: $error');
        return {'success': false, 'error': error['detail'] ?? 'Ошибка обновления'};
      }
    } catch (e) {
      print('Исключение при обновлении профиля: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUsername(String newUsername) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.put(
        Uri.parse('${AppConstants.baseUrl}/users/me/username?new_username=$newUsername'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'user': User.fromJson(jsonDecode(response.body))};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка обновления'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateBio(String bio) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.put(
        Uri.parse('${AppConstants.baseUrl}/users/me/bio'),
        headers: headers,
        body: jsonEncode({'bio': bio}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'user': User.fromJson(jsonDecode(response.body))};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка обновления'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateBirthdate(String birthdate) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.put(
        Uri.parse('${AppConstants.baseUrl}/users/me/birthdate'),
        headers: headers,
        body: jsonEncode({'birthdate': birthdate}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'user': User.fromJson(jsonDecode(response.body))};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка обновления'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateAvatarFrame(String frameId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.put(
        Uri.parse('${AppConstants.baseUrl}/users/me/avatar-frame?frame=$frameId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'avatar_frame': data['avatar_frame']};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка обновления'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadAvatar(dynamic imageSource) async {
    try {
      final token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/users/me/avatar'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      
      if (kIsWeb) {
        if (imageSource is XFile) {
          final bytes = await imageSource.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: imageSource.name,
          ));
        } else {
          throw Exception('Web platform requires XFile');
        }
      } else {
        if (imageSource is File) {
          request.files.add(await http.MultipartFile.fromPath('file', imageSource.path));
        } else if (imageSource is XFile) {
          final bytes = await imageSource.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: imageSource.name,
          ));
        } else {
          throw Exception('Invalid image source type');
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Ответ сервера (статус ${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'avatar_url': data['avatar_url']};
      } else {
        final errorMsg = 'Код ${response.statusCode}: ${response.body}';
        return {'success': false, 'error': errorMsg};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<String> getUserPublicKey(int userId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      
      final response = await _client.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.endpointKeysExchange}'),
        headers: headers,
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['public_key'] as String;
      } else {
        throw Exception('Failed to get public key: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting public key: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getChatHistory(int targetUserId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      print('Запрос истории сообщений с пользователем $targetUserId');
      
      final response = await _client.get(
        Uri.parse('${AppConstants.baseUrl}/chats/$targetUserId/messages'),
        headers: headers,
      );

      print('Ответ истории сообщений: статус ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Получено ${data.length} сообщений из истории');
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        print('Ошибка 401 при загрузке истории');
        await _authService.handle401Error();
        return [];
      } else {
        print('Ошибка загрузки истории: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Исключение при загрузке истории: $e');
      return [];
    }
  }

  Future<List<User>> getActiveChats() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        print('Токен отсутствует для /chats/active');
        return [];
      }
      
      final headers = await _authService.getAuthHeaders();
      print('Запрос к ${AppConstants.baseUrl}/chats/active');
      
      final response = await _client.get(
        Uri.parse('${AppConstants.baseUrl}/chats/active'),
        headers: headers,
      );

      print('Ответ /chats/active: статус ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => User.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        print('Ошибка 401: Токен недействителен');
        await _authService.handle401Error();
        return [];
      } else {
        print('Ошибка ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Ошибка загрузки активных чатов: $e');
      return [];
    }
  }

  Future<User> getUserProfile(int userId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.get(
        Uri.parse('${AppConstants.baseUrl}/users/$userId/profile'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading user profile: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSharedMedia(int targetUserId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.get(
        Uri.parse('${AppConstants.baseUrl}/chats/$targetUserId/media'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        return [];
      }
    } catch (e) {
      print('Error loading shared media: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> uploadFile(dynamic fileSource) async {
    try {
      final token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/upload'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      
      if (kIsWeb) {
        if (fileSource is XFile) {
          final bytes = await fileSource.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileSource.name,
          ));
        }
      } else {
        if (fileSource is File) {
          request.files.add(await http.MultipartFile.fromPath('file', fileSource.path));
        } else if (fileSource is XFile) {
          final bytes = await fileSource.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileSource.name,
          ));
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'url': data['url']};
      } else {
        return {'success': false, 'error': 'Upload failed'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getAvatarsList() async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.get(
        Uri.parse('${AppConstants.baseUrl}/avatars/list'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['avatars'] ?? []);
      }
      return [];
    } catch (e) {
      print('Ошибка получения списка аватарок: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAvatarFramesList() async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.get(
        Uri.parse('${AppConstants.baseUrl}/avatar-frames/list'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['frames'] ?? []);
      }
      return [];
    } catch (e) {
      print('Ошибка получения списка рамок: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> setPresetAvatar(String avatarId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.put(
        Uri.parse('${AppConstants.baseUrl}/users/me/preset-avatar?avatar_id=$avatarId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка установки аватарки'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setAvatarFrame(String frame) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.put(
        Uri.parse('${AppConstants.baseUrl}/users/me/avatar-frame?frame=$frame'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка установки рамки'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> clearChat(int targetUserId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.delete(
        Uri.parse('${AppConstants.baseUrl}/chats/$targetUserId/messages'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка очистки чата'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteMessage(int messageId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.delete(
        Uri.parse('${AppConstants.baseUrl}/messages/$messageId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка удаления сообщения'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> markMessagesAsRead(int targetUserId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.post(
        Uri.parse('${AppConstants.baseUrl}/chats/$targetUserId/mark-read'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка отметки сообщений'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> saveUserTheme({
    required String name,
    required String primaryColor,
    required String backgroundColor,
    required String bubbleColorMe,
    required String bubbleColorOther,
    required String textColor,
    required String secondaryTextColor,
    required String brightness,
    String? wallpaperUrl,
    String? wallpaperBlur,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.post(
        Uri.parse('${AppConstants.baseUrl}/users/me/themes'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'primary_color': primaryColor,
          'background_color': backgroundColor,
          'bubble_color_me': bubbleColorMe,
          'bubble_color_other': bubbleColorOther,
          'text_color': textColor,
          'secondary_text_color': secondaryTextColor,
          'brightness': brightness,
          'wallpaper_url': wallpaperUrl,
          'wallpaper_blur': wallpaperBlur ?? '0.0',
        }),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'theme': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка сохранения темы'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getUserThemes() async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.get(
        Uri.parse('${AppConstants.baseUrl}/users/me/themes'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> themes = jsonDecode(response.body);
        return themes.map((t) => t as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> updateUserTheme({
    required int themeId,
    required String name,
    required String primaryColor,
    required String backgroundColor,
    required String bubbleColorMe,
    required String bubbleColorOther,
    required String textColor,
    required String secondaryTextColor,
    required String brightness,
    String? wallpaperUrl,
    String? wallpaperBlur,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.put(
        Uri.parse('${AppConstants.baseUrl}/users/me/themes/$themeId'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'primary_color': primaryColor,
          'background_color': backgroundColor,
          'bubble_color_me': bubbleColorMe,
          'bubble_color_other': bubbleColorOther,
          'text_color': textColor,
          'secondary_text_color': secondaryTextColor,
          'brightness': brightness,
          'wallpaper_url': wallpaperUrl,
          'wallpaper_blur': wallpaperBlur ?? '0.0',
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'theme': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка обновления темы'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteUserTheme(int themeId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.delete(
        Uri.parse('${AppConstants.baseUrl}/users/me/themes/$themeId'),
        headers: headers,
      );

      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка удаления темы'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> setContactLocalName(int contactId, String localName) async {
    final token = await _authService.getToken();
    if (token == null) {
      await _authService.handle401Error();
      throw Exception('Не авторизован');
    }

    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/contacts/$contactId/local-name?local_name=${Uri.encodeComponent(localName)}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      await _authService.handle401Error();
      throw Exception('Не авторизован');
    }

    if (response.statusCode != 200) {
      throw Exception('Ошибка установки локального имени: ${response.statusCode}');
    }
  }

  Future<void> deleteContactLocalName(int contactId) async {
    final token = await _authService.getToken();
    if (token == null) {
      await _authService.handle401Error();
      throw Exception('Не авторизован');
    }

    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/contacts/$contactId/local-name'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      await _authService.handle401Error();
      throw Exception('Не авторизован');
    }

    if (response.statusCode != 200) {
      throw Exception('Ошибка удаления локального имени: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.delete(
        Uri.parse('${AppConstants.baseUrl}/users/me'),
        headers: headers,
      );

      if (response.statusCode == 204) {
        return {'success': true};
      } else if (response.statusCode == 401) {
        print('Ошибка 401 при удалении аккаунта');
        await _authService.handle401Error();
        return {'success': false, 'error': 'Сессия истекла. Пожалуйста, войдите снова.'};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка удаления аккаунта'};
      }
    } catch (e) {
      print('Ошибка при удалении аккаунта: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getPrivacySettings() async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.get(
        Uri.parse('${AppConstants.baseUrl}/users/me/privacy'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else if (response.statusCode == 401) {
        print('Ошибка 401 при загрузке настроек приватности');
        await _authService.handle401Error();
        return {'success': false, 'error': 'Сессия истекла. Пожалуйста, войдите снова.'};
      } else {
        return {'success': false, 'error': 'Ошибка загрузки настроек'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updatePrivacySettings({
    required String avatarVisibility,
    required List<int> avatarVisibilityExceptions,
    required bool showReadReceipts,
    required bool showLastSeen,
    required bool showOnlineStatus,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final queryParams = <String, String>{
        'avatar_visibility': avatarVisibility,
        'show_read_receipts': showReadReceipts.toString(),
        'show_last_seen': showLastSeen.toString(),
        'show_online_status': showOnlineStatus.toString(),
      };
      
      if (avatarVisibilityExceptions.isNotEmpty) {
        queryParams['avatar_visibility_exceptions'] = jsonEncode(avatarVisibilityExceptions);
      }
      
      final uri = Uri.parse('${AppConstants.baseUrl}/users/me/privacy').replace(
        queryParameters: queryParams,
      );
      
      final response = await _client.put(
        uri,
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else if (response.statusCode == 401) {
        print('Ошибка 401 при обновлении настроек приватности');
        await _authService.handle401Error();
        return {'success': false, 'error': 'Сессия истекла. Пожалуйста, войдите снова.'};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Ошибка обновления настроек'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  void dispose() {
    _client.close();
  }
}
