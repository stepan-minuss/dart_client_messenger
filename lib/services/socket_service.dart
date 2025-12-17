import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';
import 'message_notification_handler.dart';

class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String encryptedContent;
  final String messageType;
  final String? mediaUrl;
  final DateTime timestamp;
  final bool isRead;
  final int? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderName;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.encryptedContent,
    this.messageType = "text",
    this.mediaUrl,
    required this.timestamp,
    required this.isRead,
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderName,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final timestampStr = json['timestamp'] as String;
    DateTime timestamp = DateTime.parse(timestampStr);
    if (timestamp.isUtc) {
      timestamp = timestamp.toLocal();
    }
    
    return ChatMessage(
      id: json['id'] as int,
      senderId: json['sender_id'] as int,
      receiverId: json['receiver_id'] as int,
      encryptedContent: json['encrypted_content'] as String,
      messageType: json['message_type'] as String? ?? "text",
      mediaUrl: json['media_url'] as String?,
      timestamp: timestamp,
      isRead: json['is_read'] as bool? ?? false,
      replyToMessageId: json['reply_to_message_id'] as int?,
    );
  }
}

class SocketService {
  IO.Socket? _socket;
  final AuthService _authService = AuthService();
  
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _messagesReadController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageSentController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get messagesReadStream => _messagesReadController.stream;
  Stream<Map<String, dynamic>> get messageSentStream => _messageSentController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(int currentUserId) async {
    if (_socket?.connected == true) {
      return;
    }

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('No authentication token');
      }

      try {
        print('Разбудим сервер перед подключением...');
        final headers = await _authService.getAuthHeaders();
        
        final endpoints = ['/test', '/health', '/'];
        bool serverAwakened = false;
        
        for (final endpoint in endpoints) {
          try {
            final response = await http.get(
              Uri.parse('${AppConstants.baseUrl}$endpoint'),
              headers: headers,
            ).timeout(const Duration(seconds: 15));
            
            print('Сервер разбужен через $endpoint: статус ${response.statusCode}');
            serverAwakened = true;
            break;
          } catch (e) {
            print('Не удалось разбудить через $endpoint: $e');
          }
        }
        
        if (serverAwakened) {
          await Future.delayed(const Duration(milliseconds: 1000));
        } else {
          print('Не удалось разбудить сервер ни через один эндпоинт (продолжаем подключение)');
        }
      } catch (e) {
        print('Ошибка при пробуждении сервера (продолжаем): $e');
      }

      String socketUrl = AppConstants.baseUrl;
      if (socketUrl.endsWith('/')) {
        socketUrl = socketUrl.substring(0, socketUrl.length - 1);
      }

      print('Подключение к : $socketUrl')
      print('Токен присутствует: ${token.isNotEmpty}');

      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .setQuery({'token': token})
            .setTimeout(30000)
            .enableForceNew()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .build(),
      );

      final completer = Completer<void>();
      Timer? timeoutTimer;

      _socket!.onConnect((_) {
        print('Socket.IO подключен к серверу');
        _connectionController.add(true);
        if (!completer.isCompleted) {
          completer.complete();
        }
        timeoutTimer?.cancel();
      });

      _socket!.onDisconnect((data) {
        print('Socket.IO отключен: $data');
        _connectionController.add(false);
      });

      _socket!.onConnectError((error) {
        print('Ошибка Replit соединения: $error');
        print('Тип ошибки: ${error.runtimeType}');
        String errorMsg = 'Ошибка подключения: ';
        if (error is Map) {
          errorMsg += error.toString();
        } else {
          errorMsg += error.toString();
        }
        _errorController.add(errorMsg);
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
        timeoutTimer?.cancel();
      });

      _socket!.onError((error) {
        print('Ошибка Socket.IO транспорта: $error');
        print('Тип ошибки: ${error.runtimeType}');
        String errorMsg = 'Ошибка Socket.IO: ';
        if (error is Map) {
          errorMsg += error.toString();
        } else {
          errorMsg += error.toString();
        }
        _errorController.add(errorMsg);
      });

      _socket!.on('connect', (_) {
        print('Socket.IO событие connect получено');
      });

      _socket!.on('disconnect', (reason) {
        print('Socket.IO отключен: $reason');
      });

      _socket!.on('reconnect', (attemptNumber) {
        print('Socket.IO переподключен после $attemptNumber попыток');
      });

      _socket!.on('reconnect_attempt', (attemptNumber) {
        print('Попытка переподключения Socket.IO: $attemptNumber');
      });

      _socket!.on('reconnect_error', (error) {
        print('Ошибка переподключения Socket.IO: $error');
      });

      _socket!.on('reconnect_failed', (_) {
        print('Socket.IO переподключение не удалось');
      });

      timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          print('Таймаут подключения Socket.IO (30 секунд)')
          _errorController.add('Timeout: подключение не установлено за 30 секунд');
          completer.completeError('Timeout: подключение не установлено за 30 секунд');
        }
      });

      _socket!.on('new_message', (data) {
        print('Получено событие new_message: $data');
        try {
          final message = ChatMessage.fromJson(data as Map<String, dynamic>);
          print('Сообщение распарсено: id=${message.id}, sender=${message.senderId}, receiver=${message.receiverId}');
          _messageController.add(message);
          
          if (message.receiverId != null && message.senderId != null && message.receiverId != message.senderId) {
            MessageNotificationHandler.handleIncomingMessage(message);
          }
        } catch (e) {
          print('Ошибка обработки сообщения: $e');
          _errorController.add('Ошибка обработки сообщения: $e');
        }
      });

      _socket!.on('typing', (data) {
        _typingController.add(data as Map<String, dynamic>);
      });

      _socket!.on('error', (data) {
        final error = data is Map ? data['message'] : data.toString();
        _errorController.add(error);
      });

      _socket!.on('message_sent', (data) {
        print('Получено подтверждение отправки сообщения: $data');
        final eventData = data is Map ? Map<String, dynamic>.from(data) : {'message_id': 0};
        _messageSentController.add(eventData);
      });

      _socket!.on('messages_read', (data) {
        try {
          final dataMap = data as Map<String, dynamic>;
          final messageIds = (dataMap['message_ids'] as List).cast<int>();
          final readerId = dataMap['reader_id'] as int;
          _messagesReadController.add({
            'message_ids': messageIds,
            'reader_id': readerId,
          });
        } catch (e) {
          print('Ошибка обработки messages_read: $e');
        }
      });

      print('Инициируем подключение WebSocket...');
      _socket!.connect();

      await completer.future;
      print('Подключение установлено успешно');

    } catch (e) {
      print('Fatal Error при подключении: $e');
      _errorController.add('Ошибка подключения: $e');
      rethrow;
    }
  }

  Future<void> sendMessage({
    required int receiverId,
    required String encryptedContent,
    String messageType = "text",
    String? mediaUrl,
    int? replyToMessageId,
  }) async {
    print('Отправка сообщения: receiverId=$receiverId, type=$messageType, connected=${_socket?.connected}');
    
    if (_socket?.connected != true) {
      print('Socket не подключен, пытаемся переподключиться...');
      try {
        final token = await _authService.getToken();
        if (token != null) {
          final userId = await _getCurrentUserIdFromToken();
          connect(userId).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('Таймаут переподключения, продолжаем отправку...');
            },
          ).catchError((e) {
            print('Ошибка переподключения (не критично): $e');
          });
        }
      } catch (e) {
        print('Ошибка переподключения (не критично): $e');
      }
    }

    if (_socket?.connected == true) {
      try {
        final messageData = {
          'receiver_id': receiverId,
          'encrypted_content': encryptedContent,
          'message_type': messageType,
          if (mediaUrl != null) 'media_url': mediaUrl,
          if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
        };
        
        print('Отправка данных через Socket.IO: receiverId=$receiverId (type: ${receiverId.runtimeType}), messageData=$messageData');
        _socket!.emit('send_message', messageData);
        print('Сообщение отправлено через Socket.IO');
        return;
      } catch (e) {
        print('Ошибка отправки через Socket.IO: $e');
      }
    }
    
    print('Socket.IO не подключен, сообщение не может быть отправлено');
    throw Exception('Socket.IO не подключен. Пожалуйста, проверьте подключение к интернету и попробуйте снова.');
  }

  Future<int> _getCurrentUserIdFromToken() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return 0;
      
      return 0;
    } catch (e) {
      return 0;
    }
  }

  void sendTyping({
    required int receiverId,
    required bool isTyping,
  }) {
    if (_socket?.connected != true) {
      return;
    }

    _socket!.emit('typing', {
      'receiver_id': receiverId,
      'is_typing': isTyping,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _errorController.close();
    _connectionController.close();
    _messagesReadController.close();
    _messageSentController.close();
  }
}

