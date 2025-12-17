import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ConnectionTestService {
  final _client = http.Client();

  Future<Map<String, dynamic>> testConnection() async {
    final endpoints = ['/test', '/health', '/'];
    
    for (final endpoint in endpoints) {
      try {
        print('Проверка подключения к ${AppConstants.baseUrl}$endpoint');
        
        final response = await _client.get(
          Uri.parse('${AppConstants.baseUrl}$endpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('Timeout: сервер не отвечает в течение 15 секунд');
          },
        );

        print('Ответ получен: статус ${response.statusCode}');
        if (response.statusCode == 200 || response.statusCode == 404) {
          try {
            final data = jsonDecode(response.body);
            return {
              'success': true,
              'message': 'Подключение успешно!',
              'data': data,
            };
          } catch (_) {
            return {
              'success': true,
              'message': 'Подключение успешно! (статус: ${response.statusCode})',
              'data': {'status': response.statusCode},
            };
          }
        } else {
          continue;
        }
      } catch (e) {
        print('Ошибка при проверке $endpoint: $e');
        if (endpoint == endpoints.last) {
          String errorMessage = 'Ошибка подключения';
          
          if (e.toString().contains('Failed to fetch') || 
              e.toString().contains('NetworkError') ||
              e.toString().contains('SocketException') ||
              e.toString().contains('Connection refused')) {
            errorMessage = '''
Не удается подключиться к серверу.

Проверьте:
1. Backend запущен на Replit?
2. Backend доступен по адресу: ${AppConstants.baseUrl}
3. Откройте в браузере: ${AppConstants.baseUrl}/docs
4. Проверьте, нет ли блокировки файрволом
5. На Replit сервер может "засыпать" - подождите несколько секунд
            ''';
          } else if (e.toString().contains('Timeout')) {
            errorMessage = '''
Таймаут подключения. Сервер не отвечает в течение 15 секунд.

Возможные причины:
1. Сервер на Replit еще не запустился (cold start)
2. Сервер перегружен
3. Проблемы с сетью

Попробуйте:
- Подождать еще несколько секунд
- Обновить страницу/перезапустить приложение
- Проверить статус сервера: ${AppConstants.baseUrl}/health
            ''';
          } else {
            errorMessage = 'Ошибка: ${e.toString()}';
          }
          
          return {
            'success': false,
            'message': errorMessage,
          };
        }
      }
    }
    return {
      'success': false,
      'message': 'Не удалось подключиться ни к одному эндпоинту сервера',
    };
  }

  void dispose() {
    _client.close();
  }
}

