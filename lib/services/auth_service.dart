import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  final _client = http.Client();

  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required String publicKey,
  }) async {
    try {
      final url = '${AppConstants.baseUrl}${AppConstants.endpointRegister}';
      print('📡 Регистрация: отправка запроса на $url');
      
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
          'password': password,
          'public_key': publicKey,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: сервер не отвечает в течение 30 секунд');
        },
      );
      
      print('Регистрация: получен ответ ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['access_token'] as String;
        
        await _storage.write(key: AppConstants.authTokenKey, value: token);
        print('Токен сохранен после регистрации (${token.length} символов)');
        
        final savedToken = await _storage.read(key: AppConstants.authTokenKey);
        if (savedToken != token) {
          print('ВНИМАНИЕ: Токен не совпадает после сохранения!');
        }
        
        return {
          'success': true,
          'token': token,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['detail'] ?? 'Ошибка регистрации',
        };
      }
    } catch (e) {
      String errorMessage = 'Ошибка подключения';
      
      if (e is SocketException || 
          e.toString().contains('Failed to fetch') || 
          e.toString().contains('NetworkError') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('getaddrinfo failed')) {
        errorMessage = 'Не удается подключиться к серверу. Убедитесь, что backend запущен на ${AppConstants.baseUrl}';
      } else if (e.toString().contains('Timeout')) {
        errorMessage = 'Таймаут подключения. Сервер не отвечает. Проверьте, что backend запущен на ${AppConstants.baseUrl}';
      } else if (e.toString().contains('CORS')) {
        errorMessage = 'Ошибка CORS. Проверьте настройки CORS на сервере.';
      } else {
        errorMessage = 'Ошибка подключения: ${e.toString()}';
      }
      
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final url = '${AppConstants.baseUrl}${AppConstants.endpointLogin}';
      print('📡 Вход: отправка запроса на $url');
      
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: сервер не отвечает в течение 30 секунд');
        },
      );
      
      print('Вход: получен ответ ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'] as String;
        
        await _storage.write(key: AppConstants.authTokenKey, value: token);
        print('Токен сохранен после входа (${token.length} символов)');
        
        final savedToken = await _storage.read(key: AppConstants.authTokenKey);
        if (savedToken != token) {
          print('ВНИМАНИЕ: Токен не совпадает после сохранения!');
        }
        
        return {
          'success': true,
          'token': token,
        };
      } else {
        try {
          final error = jsonDecode(response.body);
          String errorMessage = 'Логин или пароль неверен';
          
          if (error['detail'] != null) {
            if (error['detail'] is List) {
              final details = error['detail'] as List;
              if (details.isNotEmpty) {
                final firstError = details[0];
                if (firstError is Map && firstError['msg'] != null) {
                  errorMessage = firstError['msg'] as String;
                } else if (firstError is String) {
                  errorMessage = firstError;
                }
              }
            } else if (error['detail'] is String) {
              errorMessage = error['detail'] as String;
            }
          }
          
          return {
            'success': false,
            'error': errorMessage,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Логин или пароль неверен',
          };
        }
      }
    } catch (e) {
      print('Ошибка входа: $e');
      String errorMessage = 'Ошибка подключения';
      
      if (e is SocketException || 
          e.toString().contains('Failed to fetch') || 
          e.toString().contains('NetworkError') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('getaddrinfo failed')) {
        errorMessage = 'Не удается подключиться к серверу. Убедитесь, что backend запущен на ${AppConstants.baseUrl}';
      } else if (e.toString().contains('Timeout')) {
        errorMessage = 'Таймаут подключения. Сервер не отвечает. Проверьте, что backend запущен на ${AppConstants.baseUrl}';
      } else if (e.toString().contains('CORS')) {
        errorMessage = 'Ошибка CORS. Проверьте настройки CORS на сервере.';
      } else if (e.toString().contains('Certificate') || e.toString().contains('TLS') || e.toString().contains('SSL')) {
        errorMessage = 'Ошибка SSL сертификата: ${e.toString()}';
      } else {
        errorMessage = 'Ошибка подключения: ${e.toString()}';
      }
      
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }

  Future<String?> getToken() async {
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) {
        print('getToken: токен не найден в хранилище');
      } else {
        print('getToken: токен найден (${token.length} символов)');
      }
      return token;
    } catch (e) {
      print('Ошибка чтения токена из хранилища: $e');
      return null;
    }
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.authTokenKey);
    print('Токен удален из хранилища');
  }
  
  Future<void> handle401Error() async {
    print('Обнаружена ошибка 401 - выполняем выход из системы');
    await logout();
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token == null) {
      print('getAuthHeaders: токен отсутствует');
    } else {
      print('getAuthHeaders: токен присутствует (${token.length} символов)');
    }
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}

