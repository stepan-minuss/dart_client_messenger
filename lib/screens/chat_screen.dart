import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/socket_service.dart';
import '../services/security_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/theme_service.dart';
import '../models/app_theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/avatar_with_frame.dart';
import '../utils/constants.dart';
import '../utils/jwt_helper.dart';
import '../utils/refresh_bus.dart';
import '../utils/display_name_helper.dart';
import '../services/message_cache_service.dart';
import '../services/contact_cache_service.dart';
import '../services/open_chat_tracker.dart';
import '../utils/image_cache_config.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'user_profile_screen.dart';
import 'image_viewer_screen.dart';

class ChatScreen extends StatefulWidget {
  final int chatUserId;
  final String chatUsername;
  final VoidCallback? onMessageSent;
  final int? initialReplyToMessageId; 
  final String? initialMessageText; 

  const ChatScreen({
    super.key,
    required this.chatUserId,
    required this.chatUsername,
    this.onMessageSent,
    this.initialReplyToMessageId,
    this.initialMessageText,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final SocketService _socketService;
  final _securityService = SecurityService();
  final _authService = AuthService();
  final _jwtHelper = JwtHelper();
  final _userService = UserService();
  final _picker = ImagePicker();
  final _messageCacheService = MessageCacheService();
  
  List<ChatMessage> _messages = [];
  final Set<int> _messageIds = {};
  int? _oldestMessageId; 
  bool _isTyping = false;
  bool _isConnected = false;
  bool _isLoadingMessages = false; 
  bool _showEmojiPicker = false;
  bool _showSearch = false;
  String _searchQuery = '';
  ChatMessage? _replyingTo; 
  bool _isChatCleared = false; 
  int? _currentUserId;
  User? _chatPartner;
  Contact? _deviceContact; 
  Timer? _statusUpdateTimer;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _messagesReadSubscription;
  StreamSubscription? _messageSentSubscription;
  late FocusNode _focusNode;
  final TextEditingController _searchController = TextEditingController();
  String? _wallpaperPath;
  double _wallpaperBlurLevel = 0.0; 
  double _cornerRadius = 18.0; 
  double _messageOpacity = 0.6; 
  double _messageBlur = 15.0; 
  double _appBarOpacity = 0.3; 
  double _appBarBlur = 10.0; 
  double _inputPanelOpacity = 0.4; 
  double _inputPanelBlur = 15.0; 

  @override
  void initState() {
    super.initState();
    OpenChatTracker.registerOpenChat(widget.chatUserId);
    
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
    _messageController.addListener(_onMessageChanged);
    _socketService = Provider.of<SocketService>(context, listen: false);
    _loadWallpaperSettings();
    _loadCornerRadius();
    _loadGlassSettings();
    _initializeChat();
  }

  Future<void> _loadCornerRadius() async {
    final prefs = await SharedPreferences.getInstance();
    final radius = prefs.getDouble('message_corner_radius') ?? 18.0;
    setState(() {
      _cornerRadius = radius;
    });
  }

  Future<void> _loadGlassSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _messageOpacity = prefs.getDouble('message_opacity') ?? 0.6;
      _messageBlur = prefs.getDouble('message_blur') ?? 15.0;
      _appBarOpacity = prefs.getDouble('appbar_opacity') ?? 0.3;
      _appBarBlur = prefs.getDouble('appbar_blur') ?? 10.0;
      _inputPanelOpacity = prefs.getDouble('input_panel_opacity') ?? 0.4;
      _inputPanelBlur = prefs.getDouble('input_panel_blur') ?? 15.0;
    });
  }

  Future<void> _loadWallpaperSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final chatKey = 'wallpaper_${widget.chatUserId}';
    final blurKey = 'wallpaper_blur_${widget.chatUserId}';
    
    final localWallpaper = prefs.getString(chatKey);
    final localBlur = prefs.getDouble(blurKey);
    
    if (localWallpaper == null) {
      final globalWallpaper = prefs.getString('global_wallpaper');
      final globalBlur = prefs.getDouble('global_wallpaper_blur') ?? 0.0;
      setState(() {
        _wallpaperPath = globalWallpaper;
        _wallpaperBlurLevel = globalBlur;
      });
    } else {
      setState(() {
        _wallpaperPath = localWallpaper;
        _wallpaperBlurLevel = localBlur ?? 0.0;
      });
    }
  }

  Future<void> _saveWallpaperSettings(String? path, double blurLevel) async {
    final prefs = await SharedPreferences.getInstance();
    final chatKey = 'wallpaper_${widget.chatUserId}';
    final blurKey = 'wallpaper_blur_${widget.chatUserId}';
    if (path != null) {
      await prefs.setString(chatKey, path);
    } else {
      await prefs.remove(chatKey);
    }
    await prefs.setDouble(blurKey, blurLevel);
    setState(() {
      _wallpaperPath = path;
      _wallpaperBlurLevel = blurLevel;
    });
  }

  Future<void> _initializeChat() async {
    final token = await _authService.getToken();
    if (token == null) {
      _showError('Не авторизован');
      return;
    }

    _currentUserId = await _jwtHelper.getCurrentUserId();
    if (_currentUserId == null) {
      _showError('Не удалось получить ID пользователя');
      return;
    }
    
    print('Инициализация чата: _currentUserId=$_currentUserId, chatUserId=${widget.chatUserId}');
    
    if (_currentUserId == widget.chatUserId) {
      print('ВНИМАНИЕ: Попытка открыть чат с самим собой!');
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    _loadChatHistory(loadFromCache: true).then((_) {
      if (widget.initialReplyToMessageId != null) {
        final replyToMessage = _messages.firstWhere(
          (msg) => msg.id == widget.initialReplyToMessageId,
          orElse: () => ChatMessage(
            id: 0,
            senderId: 0,
            receiverId: 0,
            encryptedContent: '',
            timestamp: DateTime.now(),
            isRead: false,
          ),
        );
        if (replyToMessage.id != 0) {
          setState(() {
            _replyingTo = replyToMessage;
          });
        }
      }
      
      if (widget.initialMessageText != null) {
        _messageController.text = widget.initialMessageText!;
      }
    }).catchError((e) {
      print('Ошибка загрузки истории из кэша: $e');
    });
    
    _loadChatPartner().catchError((e) {
      print('Ошибка загрузки информации о собеседнике: $e');
    });
    
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _loadChatPartner();
    });

    try {
      print('Начинаем подключение к Socket.IO для пользователя $_currentUserId');
      _socketService.connect(_currentUserId!).timeout(
        const Duration(seconds: 45), 
        onTimeout: () {
          print('Таймаут подключения Socket.IO (45 секунд), продолжаем работу...');
          if (mounted) {
          }
        },
      ).then((_) {
        print('Socket.IO подключение успешно установлено');
        if (mounted) {
          setState(() {
            _isConnected = true;
          });
        }
      }).catchError((e) {
        print('Ошибка подключения Socket.IO (не критично): $e');
        if (mounted) {
        }
      });
      
      _messageSubscription = _socketService.messageStream.listen((message) {
        print('Получено сообщение в ChatScreen: ${message.encryptedContent}');
        _handleNewMessage(message);
      });

      _typingSubscription = _socketService.typingStream.listen((data) {
        if (data['sender_id'] == widget.chatUserId) {
          setState(() {
            _isTyping = data['is_typing'] as bool? ?? false;
          });
        }
      });

      _errorSubscription = _socketService.errorStream.listen((error) {
        print('Ошибка Socket.IO: $error');
        if (!error.contains('Timeout')) {
          _showError(error);
        }
      });

      _connectionSubscription = _socketService.connectionStream.listen((connected) {
        setState(() {
          _isConnected = connected;
        });
      });

      _messagesReadSubscription = _socketService.messagesReadStream.listen((data) {
        final messageIds = (data['message_ids'] as List).cast<int>();
        final readerId = data['reader_id'] as int;
        
        if (mounted && readerId == widget.chatUserId) {
          bool hasChanges = false;
          for (var msg in _messages) {
            if (messageIds.contains(msg.id) && msg.senderId == _currentUserId && !msg.isRead) {
              final index = _messages.indexWhere((m) => m.id == msg.id);
              if (index != -1) {
                final updatedMessage = ChatMessage(
                  id: msg.id,
                  senderId: msg.senderId,
                  receiverId: msg.receiverId,
                  encryptedContent: msg.encryptedContent,
                  messageType: msg.messageType,
                  mediaUrl: msg.mediaUrl,
                  timestamp: msg.timestamp,
                  isRead: true,
                  replyToMessageId: msg.replyToMessageId,
                  replyToText: msg.replyToText,
                  replyToSenderName: msg.replyToSenderName,
                );
                _messages[index] = updatedMessage;
                _messageCacheService.updateMessageInCache(widget.chatUserId, updatedMessage);
                hasChanges = true;
              }
            }
          }
          if (hasChanges && mounted) {
            setState(() {});
          }
        }
      });
      
      _messageSentSubscription = _socketService.messageSentStream.listen((data) {
        print('Получено подтверждение отправки, обновляем активные чаты');
        Future.delayed(const Duration(milliseconds: 500), () {
          RefreshBus.notifyActiveChats();
        });
      });
    } catch (e) {
      _showError('Ошибка подключения: $e');
    }
  }

  Future<void> _loadChatPartner() async {
    try {
      final partner = await _userService.getUserProfile(widget.chatUserId);
      
      Contact? deviceContact;
      if (partner.phone != null && partner.phone!.isNotEmpty) {
        try {
          final contactMap = await ContactCacheService.getCachedContactMap();
          final normalizedPhone = partner.phone!.replaceAll(RegExp(r'[^\d]'), '');
          deviceContact = contactMap[normalizedPhone];
          
          if (deviceContact == null && normalizedPhone.length >= 10) {
            deviceContact = contactMap[normalizedPhone.substring(normalizedPhone.length - 10)];
          }
        } catch (e) {
          print('Ошибка загрузки контакта из кеша: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _chatPartner = partner;
          _deviceContact = deviceContact;
        });
      }
    } catch (e) {
      print('Не удалось загрузить информацию о собеседнике: $e');
      if (mounted) {
        setState(() {
          _chatPartner = User(id: widget.chatUserId, username: widget.chatUsername);
          _deviceContact = null;
        });
      }
    }
  }
  
  String _getPartnerDisplayName() {
    if (_chatPartner == null) {
      return widget.chatUsername;
    }
    
    return DisplayNameHelper.getDisplayName(_chatPartner!, deviceContact: _deviceContact);
  }

  Future<void> _loadChatHistory({bool loadFromCache = true}) async {
    if (_isChatCleared) {
      print('Чат был очищен, пропускаем загрузку истории');
      return;
    }
    
    print('Загрузка истории чата с пользователем ${widget.chatUserId}');
    
    List<ChatMessage>? cachedMessages;
    if (loadFromCache) {
      try {
        cachedMessages = await _messageCacheService.getCachedMessages(widget.chatUserId);
        if (cachedMessages != null && cachedMessages.isNotEmpty) {
          print('Загружено ${cachedMessages.length} сообщений из кеша');
          
          final validCachedMessages = cachedMessages!.where((msg) => msg.id < 1000000000000).toList();
          
          validCachedMessages.sort((a, b) {
            final timeCompare = a.timestamp.compareTo(b.timestamp);
            if (timeCompare != 0) return timeCompare;
            return a.id.compareTo(b.id);
          });
          
          if (mounted) {
            setState(() {
              _messages.clear();
              _messageIds.clear();
              _messages.addAll(validCachedMessages);
              _messageIds.addAll(validCachedMessages.map((m) => m.id));
              _isLoadingMessages = false;
              if (_messages.isNotEmpty) {
                _oldestMessageId = _messages.map((m) => m.id).reduce((a, b) => a < b ? a : b);
              }
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }
          
          Future(() async {
            try {
              final Map<int, ChatMessage> messageMap = {};
              for (var msg in cachedMessages!) {
                messageMap[msg.id] = msg;
              }
              
              int? currentUserId = _currentUserId;
              if (currentUserId == null) {
                currentUserId = await _jwtHelper.getCurrentUserId();
              }
              
              bool hasChanges = false;
              final List<ChatMessage> updatedMessages = [];
              
              for (var msg in cachedMessages!) {
                if (msg.id >= 1000000000000) {
                  continue;
                }
                
                if (msg.replyToMessageId != null && (msg.replyToText == null || msg.replyToSenderName == null)) {
                  final replyToMsg = messageMap[msg.replyToMessageId];
                  if (replyToMsg != null) {
                    updatedMessages.add(ChatMessage(
                      id: msg.id,
                      senderId: msg.senderId,
                      receiverId: msg.receiverId,
                      encryptedContent: msg.encryptedContent,
                      messageType: msg.messageType,
                      mediaUrl: msg.mediaUrl,
                      timestamp: msg.timestamp,
                      isRead: msg.isRead,
                      replyToMessageId: msg.replyToMessageId,
                      replyToText: msg.replyToText ?? (replyToMsg.messageType == 'image' ? '📷 Фото' : replyToMsg.encryptedContent),
                      replyToSenderName: msg.replyToSenderName ?? (replyToMsg.senderId == currentUserId ? 'Вам' : widget.chatUsername),
                    ));
                    hasChanges = true;
                  } else {
                    updatedMessages.add(msg);
                  }
                } else {
                  updatedMessages.add(msg);
                }
              }
              
              if (hasChanges && mounted) {
                setState(() {
                  _messages.clear();
                  _messages.addAll(updatedMessages);
                });
                await _messageCacheService.cacheMessages(widget.chatUserId, updatedMessages);
              }
            } catch (e) {
              print('Ошибка восстановления replyToText: $e');
            }
          });
        } else {
          if (mounted) {
            setState(() {
              _isLoadingMessages = true;
            });
          }
        }
      } catch (e) {
        print('Ошибка загрузки из кэша: $e');
      }
    }
    
    Future(() async {
      try {
        final history = await _userService.getChatHistory(widget.chatUserId);
        print('Получено ${history.length} сообщений с сервера для пользователя ${widget.chatUserId}');
        
        if (history.isEmpty) {
          print('История сообщений пуста - это может быть новый чат или сообщения еще не отправлены');
          if (cachedMessages != null && cachedMessages.isNotEmpty && mounted) {
            await _messageCacheService.cacheMessages(widget.chatUserId, cachedMessages);
            print('Обновлен timestamp кэша для ${cachedMessages.length} сообщений');
          }
          return;
        }
        
        final List<ChatMessage> decryptedMessages = [];
        final Set<int> processedIds = {};
        
        final cachedMessageIds = cachedMessages != null 
            ? cachedMessages.map((m) => m.id).toSet()
            : <int>{};
        
        for (var msgData in history) {
          try {
            final message = ChatMessage.fromJson(msgData);
            
            if (processedIds.contains(message.id)) {
              continue;
            }
            processedIds.add(message.id);
            
            final DateTime localTimestamp = message.timestamp;
            
            final displayContent = await _securityService.decryptMessage(message.encryptedContent);
            
            String? replyToText;
            String? replyToSenderName;
            if (message.replyToMessageId != null) {
              ChatMessage replyToMessage = ChatMessage(
                id: 0,
                senderId: 0,
                receiverId: 0,
                encryptedContent: '',
                timestamp: DateTime.now(),
                isRead: false,
              );
              final foundInDecrypted = decryptedMessages.firstWhere(
                (msg) => msg.id == message.replyToMessageId,
                orElse: () => replyToMessage,
              );
              if (foundInDecrypted.id != 0) {
                replyToMessage = foundInDecrypted;
              } else {
                replyToMessage = _messages.firstWhere(
                  (msg) => msg.id == message.replyToMessageId,
                  orElse: () => replyToMessage,
                );
              }
              if (replyToMessage.id != 0) {
                replyToText = replyToMessage.messageType == 'image'
                    ? '📷 Фото'
                    : replyToMessage.encryptedContent;
                replyToSenderName = replyToMessage.senderId == _currentUserId
                    ? 'Вам'
                    : (_chatPartner != null 
                        ? _getPartnerDisplayName()
                        : widget.chatUsername);
              }
            }
            
            decryptedMessages.add(ChatMessage(
              id: message.id,
              senderId: message.senderId,
              receiverId: message.receiverId,
              encryptedContent: displayContent,
              messageType: message.messageType,
              mediaUrl: message.mediaUrl,
              timestamp: localTimestamp,
              isRead: message.isRead,
              replyToMessageId: message.replyToMessageId,
              replyToText: replyToText,
              replyToSenderName: replyToSenderName,
            ));
          } catch (e) {
            print('Не удалось расшифровать сообщение ${msgData['id']}: $e');
          }
        }
        
        final Map<int, ChatMessage> mergedMessages = {};
        final Set<int> serverMessageIds = {};
        
        if (cachedMessages != null) {
          for (var msg in cachedMessages) {
            if (msg.id < 1000000000000) {
              mergedMessages[msg.id] = msg;
            }
          }
        }
        
        for (var msg in decryptedMessages) {
          serverMessageIds.add(msg.id);
          final cachedMsg = mergedMessages[msg.id];
          if (cachedMsg != null) {
            mergedMessages[msg.id] = ChatMessage(
              id: msg.id,
              senderId: msg.senderId,
              receiverId: msg.receiverId,
              encryptedContent: msg.encryptedContent,
              messageType: msg.messageType,
              mediaUrl: msg.mediaUrl ?? cachedMsg.mediaUrl,
              timestamp: msg.timestamp,
              isRead: msg.isRead,
              replyToMessageId: msg.replyToMessageId,
              replyToText: cachedMsg.replyToText ?? msg.replyToText,
              replyToSenderName: cachedMsg.replyToSenderName ?? msg.replyToSenderName,
            );
          } else {
            mergedMessages[msg.id] = msg;
            print('Найдено новое сообщение с сервера (ID: ${msg.id}), которого нет в кэше');
          }
        }
        
        if (cachedMessages != null) {
          final missingFromServer = cachedMessages.where((msg) => 
            !serverMessageIds.contains(msg.id) && msg.id < 1000000000000
          ).toList();
          
          if (missingFromServer.isNotEmpty) {
            print('Найдено ${missingFromServer.length} сообщений в кэше, которых нет на сервере (возможно еще не синхронизировались)');
            for (var msg in missingFromServer) {
              print('  - Сообщение ID: ${msg.id}, тип: ${msg.messageType}, время: ${msg.timestamp}');
            }
          }
        }
        
        final newFromServer = decryptedMessages.where((msg) => 
          cachedMessages == null || !cachedMessages.any((cached) => cached.id == msg.id)
        ).toList();
        
        if (newFromServer.isNotEmpty) {
          print('Найдено ${newFromServer.length} новых сообщений с сервера, которых нет в кэше');
          for (var msg in newFromServer) {
            print('  - Сообщение ID: ${msg.id}, тип: ${msg.messageType}, время: ${msg.timestamp}');
          }
        }
        
        final List<ChatMessage> finalMessages = mergedMessages.values
            .where((msg) => msg.id < 1000000000000)
            .toList();
        
        finalMessages.sort((a, b) {
          final timeCompare = a.timestamp.compareTo(b.timestamp);
          if (timeCompare != 0) return timeCompare;
          return a.id.compareTo(b.id);
        });
        
        final Map<int, ChatMessage> uniqueMessages = {};
        for (var msg in finalMessages) {
          if (!uniqueMessages.containsKey(msg.id)) {
            uniqueMessages[msg.id] = msg;
          } else {
            print('Обнаружен дубликат сообщения ID: ${msg.id}, пропускаем');
          }
        }
        final List<ChatMessage> deduplicatedMessages = uniqueMessages.values.toList();
        deduplicatedMessages.sort((a, b) {
          final timeCompare = a.timestamp.compareTo(b.timestamp);
          if (timeCompare != 0) return timeCompare;
          return a.id.compareTo(b.id);
        });
        
        await _messageCacheService.cacheMessages(widget.chatUserId, deduplicatedMessages);
        
        if (mounted) {
          final bool wasAtBottom = _scrollController.hasClients && 
              (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50);
          
          setState(() {
            _messages.clear();
            _messageIds.clear();
            _messages.addAll(deduplicatedMessages);
            _messageIds.addAll(deduplicatedMessages.map((m) => m.id));
            if (_messages.isNotEmpty) {
              _oldestMessageId = _messages.map((m) => m.id).reduce((a, b) => a < b ? a : b);
            }
          });
          
          if (!loadFromCache || cachedMessages == null || wasAtBottom) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 150), () {
                _scrollToBottom();
              });
            });
          }
          
          _markMessagesAsRead();
        }
      } catch (e) {
        print('Ошибка загрузки истории с сервера: $e');
      }
    });
  }

  Future<void> _handleNewMessage(ChatMessage message) async {
    print('_handleNewMessage: sender=${message.senderId}, receiver=${message.receiverId}, myId=$_currentUserId, chatUserId=${widget.chatUserId}');
    
    bool isFromChatUser = message.senderId == widget.chatUserId && message.receiverId == _currentUserId;
    bool isToChatUser = message.senderId == _currentUserId && message.receiverId == widget.chatUserId;
    
    if (!isFromChatUser && !isToChatUser) {
      print('Сообщение не для этого чата, игнорируем');
      return;
    }
    
    if (isToChatUser) {
      print('Это наше сообщение (синхронизация), заменяем временное на реальное');
      
      try {
        final displayContent = await _securityService.decryptMessage(message.encryptedContent);
        
        final tempIndex = _messages.indexWhere((m) => 
          m.id != message.id && 
          m.encryptedContent == displayContent && 
          m.senderId == _currentUserId &&
          m.receiverId == widget.chatUserId
        );
        
        final realMessage = ChatMessage(
          id: message.id,
          senderId: message.senderId,
          receiverId: message.receiverId,
          encryptedContent: displayContent,
          messageType: message.messageType,
          mediaUrl: message.mediaUrl,
          timestamp: message.timestamp,
          isRead: message.isRead,
          replyToMessageId: message.replyToMessageId,
          replyToText: message.replyToMessageId != null ? 
            _messages.firstWhere(
              (m) => m.id == message.replyToMessageId,
              orElse: () => ChatMessage(
                id: 0, senderId: 0, receiverId: 0,
                encryptedContent: '', timestamp: DateTime.now(), isRead: false,
              ),
            ).encryptedContent : null,
          replyToSenderName: message.replyToMessageId != null ?
            (_messages.firstWhere(
              (m) => m.id == message.replyToMessageId,
              orElse: () => ChatMessage(
                id: 0, senderId: 0, receiverId: 0,
                encryptedContent: '', timestamp: DateTime.now(), isRead: false,
              ),
            ).senderId == _currentUserId ? 'Вам' : 
             (_chatPartner != null 
                ? _getPartnerDisplayName()
                : widget.chatUsername)) : null,
        );
        
        if (tempIndex != -1) {
          final tempId = _messages[tempIndex].id;
          
          setState(() {
            _messages[tempIndex] = realMessage;
            _messageIds.remove(tempId);
            _messageIds.add(realMessage.id);
            _messages.sort((a, b) {
              final timeCompare = a.timestamp.compareTo(b.timestamp);
              if (timeCompare != 0) return timeCompare;
              return a.id.compareTo(b.id);
            });
          });
          
          if (tempId != realMessage.id) {
            _messageCacheService.removeMessageFromCache(widget.chatUserId, tempId).catchError((e) {
              print('Ошибка удаления временного сообщения из кэша: $e');
            });
          }
          _messageCacheService.addMessageToCache(widget.chatUserId, realMessage).catchError((e) {
            print('Ошибка кеширования реального сообщения: $e');
          });
        } else {
          if (!_messageIds.contains(realMessage.id)) {
            setState(() {
              _messages.add(realMessage);
              _messageIds.add(realMessage.id);
              _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            });
            _messageCacheService.addMessageToCache(widget.chatUserId, realMessage).catchError((e) {
              print('Ошибка кеширования реального сообщения: $e');
            });
          }
        }
      } catch (e) {
        print('Ошибка обработки синхронизированного сообщения: $e');
      }
      return;
    }
    
    if (_messageIds.contains(message.id)) {
      print('Дубликат входящего сообщения, пропускаем');
      return;
    }
    
    try {
      print('Расшифровываем входящее сообщение...');
      final displayContent = await _securityService.decryptMessage(message.encryptedContent);
      print('Расшифровка успешна: $displayContent');
      
      final DateTime receivedAt = DateTime.now().toLocal();
      
      String? replyToText;
      String? replyToSenderName;
      if (message.replyToMessageId != null) {
        final replyToMessage = _messages.firstWhere(
          (msg) => msg.id == message.replyToMessageId,
          orElse: () => ChatMessage(
            id: 0,
            senderId: 0,
            receiverId: 0,
            encryptedContent: '',
            timestamp: DateTime.now(),
            isRead: false,
          ),
        );
        if (replyToMessage.id != 0) {
          replyToText = replyToMessage.messageType == 'image'
              ? '📷 Фото'
              : replyToMessage.encryptedContent;
          replyToSenderName = replyToMessage.senderId == _currentUserId
              ? 'Вам'
              : (_chatPartner != null 
                  ? _getPartnerDisplayName()
                  : widget.chatUsername);
        }
      }
      
      final decryptedMessage = ChatMessage(
        id: message.id,
        senderId: message.senderId,
        receiverId: message.receiverId,
        encryptedContent: displayContent,
        messageType: message.messageType,
        mediaUrl: message.mediaUrl,
        timestamp: receivedAt,
        isRead: true,
        replyToMessageId: message.replyToMessageId,
        replyToText: replyToText,
        replyToSenderName: replyToSenderName,
      );
      
      if (!_messageIds.contains(message.id)) {
        _messageIds.add(message.id);
        _messages.add(decryptedMessage);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        if (mounted) {
          setState(() {});
        }
      }

      _messageCacheService.addMessageToCache(widget.chatUserId, decryptedMessage).catchError((e) {
        print('Ошибка кеширования входящего сообщения: $e');
      });

      print('Сообщение добавлено в список (${_messages.length} всего)');
      
      _markMessagesAsRead();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToBottom();
        });
      });
    } catch (e) {
      print('Ошибка обработки сообщения: $e');
      _showError('Ошибка расшифровки: $e');
    }
  }

  void _showClearChatDialog(AppTheme theme) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: theme.backgroundColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Очистить чат?',
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                const SizedBox(height: 16),
                Text(
                  'Все сообщения будут удалены из этого чата. Это действие нельзя отменить.',
                  style: TextStyle(color: theme.secondaryTextColor),
                ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: Text(
                          'Отмена',
                          style: TextStyle(color: theme.secondaryTextColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            final result = await _userService.clearChat(widget.chatUserId);
                            if (result['success'] == true) {
                              setState(() {
                                _messages.clear();
                                _messageIds.clear();
                                _isChatCleared = true;
                              });
                              await _messageCacheService.clearCache(widget.chatUserId);
                            } else {
                              _showError(result['error'] ?? 'Ошибка очистки чата');
                            }
                          } catch (e) {
                            _showError('Ошибка очистки: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Очистить'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMediaGallery(AppTheme theme) {
    final mediaMessages = _messages.where((msg) => msg.messageType == 'image').toList();
    
    if (mediaMessages.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              'Медиа (${mediaMessages.length})',
              style: const TextStyle(color: Colors.white),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: mediaMessages.length,
            itemBuilder: (context, index) {
              final message = mediaMessages[index];
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ImageViewerScreen(imageUrl: message.mediaUrl!),
                    ),
                  );
                },
                child: ImageCacheConfig.messageMediaImage(
                  imageUrl: message.mediaUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.error, color: Colors.red),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_currentUserId == null) {
      _currentUserId = await _jwtHelper.getCurrentUserId();
      if (_currentUserId == null || _currentUserId == widget.chatUserId) {
        return;
      }
    }

    final replyingTo = _replyingTo;
    final replyToText = replyingTo?.messageType == 'image' 
        ? '📷 Фото' 
        : replyingTo?.encryptedContent;
    final replyToSenderName = replyingTo?.senderId == _currentUserId 
        ? 'Вам' 
        : (_chatPartner != null 
            ? _getPartnerDisplayName()
            : widget.chatUsername);
    
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now().toLocal();
    
    final tempMessage = ChatMessage(
      id: tempId,
      senderId: _currentUserId!,
      receiverId: widget.chatUserId,
      encryptedContent: text,
      messageType: 'text',
      timestamp: now,
      isRead: false,
      replyToMessageId: replyingTo?.id,
      replyToText: replyToText,
      replyToSenderName: replyToSenderName,
    );

    setState(() {
      _messageIds.add(tempId);
      _messages.add(tempMessage);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _replyingTo = null;
    });
    _messageController.clear();
    
    _messageCacheService.addMessageToCache(widget.chatUserId, tempMessage).catchError((e) {
      print('Ошибка кеширования временного сообщения: $e');
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    });

      widget.onMessageSent?.call();

    _sendMessageAsync(text, replyingTo?.id, tempId);
  }

  Future<void> _sendMessageAsync(String text, int? replyToMessageId, int tempId) async {
    try {
      final recipientPublicKey = await _userService.getUserPublicKey(widget.chatUserId);
      final encryptedContent = await _securityService.encryptMessage(text, recipientPublicKey);
      
      await _socketService.sendMessage(
        receiverId: widget.chatUserId,
        encryptedContent: encryptedContent,
        messageType: 'text',
        replyToMessageId: replyToMessageId,
      );

    } catch (e) {
      print('Ошибка отправки сообщения: $e');
      if (mounted) {
      setState(() {
          _messages.removeWhere((m) => m.id == tempId);
          _messageIds.remove(tempId);
      });
      _showError('Ошибка отправки: $e');
      }
    }
  }

  Future<void> _sendImage() async {
    if (_currentUserId == null) {
      _currentUserId = await _jwtHelper.getCurrentUserId();
      if (_currentUserId == null) {
        _showError('Не удалось определить текущего пользователя');
        return;
      }
    }

    print('Проверка отправки изображения: _currentUserId=$_currentUserId, widget.chatUserId=${widget.chatUserId}');
    if (_currentUserId == widget.chatUserId) {
      print('Попытка отправить изображение самому себе!');
      _showError('Нельзя отправить сообщение самому себе');
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image == null) return;

      final uploadResult = await _userService.uploadFile(image);
      if (uploadResult['success'] != true) {
        _showError('Ошибка загрузки: ${uploadResult['error']}');
        return;
      }

      final mediaUrl = uploadResult['url'] as String;

      final recipientPublicKey = await _userService.getUserPublicKey(widget.chatUserId);
      
      final encryptedContent = await _securityService.encryptMessage(mediaUrl, recipientPublicKey);

      final tempId = DateTime.now().millisecondsSinceEpoch;
      final tempImageMessage = ChatMessage(
        id: tempId,
        senderId: _currentUserId!,
        receiverId: widget.chatUserId,
        encryptedContent: mediaUrl,
        messageType: 'image',
        mediaUrl: mediaUrl,
        timestamp: DateTime.now().toLocal(),
        isRead: false,
      );
      
      setState(() {
        _messageIds.add(tempId);
        _messages.add(tempImageMessage);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      
      _messageCacheService.addMessageToCache(widget.chatUserId, tempImageMessage).catchError((e) {
        print('Ошибка кеширования временного изображения: $e');
      });
      
      _scrollToBottom();

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      _socketService.sendMessage(
        receiverId: widget.chatUserId,
        encryptedContent: encryptedContent,
        messageType: 'image',
        mediaUrl: mediaUrl,
      ).catchError((e) {
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m.id == tempId);
            _messageIds.remove(tempId);
          });
        }
      });

      widget.onMessageSent?.call();

    } catch (e) {
      _showError('Ошибка отправки изображения: $e');
    }
  }

  void _markMessagesAsRead() {
    _userService.markMessagesAsRead(widget.chatUserId).then((result) {
      if (result['success'] == true && mounted) {
        setState(() {
          for (var msg in _messages) {
            if (msg.senderId == widget.chatUserId && msg.receiverId == _currentUserId) {
              final index = _messages.indexWhere((m) => m.id == msg.id);
              if (index != -1 && !_messages[index].isRead) {
                _messages[index] = ChatMessage(
                  id: msg.id,
                  senderId: msg.senderId,
                  receiverId: msg.receiverId,
                  encryptedContent: msg.encryptedContent,
                  messageType: msg.messageType,
                  mediaUrl: msg.mediaUrl,
                  timestamp: msg.timestamp,
                  isRead: true,
                  replyToMessageId: msg.replyToMessageId,
                  replyToText: msg.replyToText,
                  replyToSenderName: msg.replyToSenderName,
                );
              }
            }
          }
        });
      }
    }).catchError((e) {
      print('Ошибка отметки сообщений как прочитанных: $e');
    });
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final messageId = message.id;
    
    final isTemporaryMessage = messageId > 1000000000000;
    
    setState(() {
      _messages.removeWhere((m) => m.id == messageId);
      _messageIds.remove(messageId);
    });
    
    if (!isTemporaryMessage) {
      await _messageCacheService.removeMessageFromCache(widget.chatUserId, messageId);
    }
    
    if (!isTemporaryMessage) {
      try {
        final result = await _userService.deleteMessage(messageId);
        if (result['success'] != true && mounted) {
          setState(() {
            if (!_messageIds.contains(messageId)) {
              _messageIds.add(messageId);
              _messages.add(message);
              _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            if (!_messageIds.contains(messageId)) {
              _messageIds.add(messageId);
              _messages.add(message);
              _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            }
          });
        }
        print('Ошибка удаления сообщения: $e');
      }
    } else {
      print('Удалено временное сообщение (не отправлено на сервер)');
    }
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          try {
            final maxScroll = _scrollController.position.maxScrollExtent;
            if (maxScroll > 0) {
              _scrollController.jumpTo(maxScroll);
            }
          } catch (e) {
            print('Ошибка прокрутки: $e');
          }
        }
      });
    });
  }

  String _getLastSeenText() {
    if (_currentUserId == null) {
      return 'загрузка...';
    }

    if (_currentUserId == widget.chatUserId) {
      return '';
    }
    
    if (_chatPartner == null) {
      _loadChatPartner();
      return 'загрузка...';
    }
    
    if (_chatPartner!.isOnline == true) {
      return 'в сети';
    }
    
    if (_chatPartner!.lastSeen == null) {
      return 'был(а) недавно';
    }

    final now = DateTime.now();
    final lastSeen = _chatPartner!.lastSeen!;
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'был(а) только что';
    } else if (difference.inMinutes < 60) {
      return 'был(а) ${difference.inMinutes} мин. назад';
    } else if (difference.inHours < 24) {
      if (now.day == lastSeen.day && now.month == lastSeen.month && now.year == lastSeen.year) {
        return 'был(а) сегодня в ${DateFormat('HH:mm').format(lastSeen)}';
      } else {
        final yesterday = now.subtract(const Duration(days: 1));
        if (yesterday.day == lastSeen.day && yesterday.month == lastSeen.month && yesterday.year == lastSeen.year) {
          return 'был(а) вчера в ${DateFormat('HH:mm').format(lastSeen)}';
        } else {
          return 'был(а) ${DateFormat('dd.MM.yyyy HH:mm').format(lastSeen)}';
        }
      }
    } else if (difference.inDays < 7) {
      return 'был(а) ${difference.inDays} ${_pluralize(difference.inDays, 'день', 'дня', 'дней')} назад в ${DateFormat('HH:mm').format(lastSeen)}';
    } else {
      return 'был(а) ${DateFormat('dd.MM.yyyy HH:mm').format(lastSeen)}';
    }
  }

  String _pluralize(int count, String one, String few, String many) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    
    if (mod10 == 1 && mod100 != 11) {
      return one;
    } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return few;
    } else {
      return many;
    }
  }

  void _showError(String message) {
  }

  void _onMessageChanged() {
  }

  @override
  void dispose() {
    OpenChatTracker.unregisterOpenChat(widget.chatUserId);
    
    _messageController.removeListener(_onMessageChanged);
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _errorSubscription?.cancel();
    _connectionSubscription?.cancel();
    _messagesReadSubscription?.cancel();
    _messageSentSubscription?.cancel();
    _statusUpdateTimer?.cancel();
    _jwtHelper.dispose();
    _userService.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.currentTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: _appBarBlur, sigmaY: _appBarBlur),
            child: AppBar(
              backgroundColor: theme.backgroundColor.withOpacity(_appBarOpacity),
              elevation: 0,
              titleSpacing: 0,
              title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(
                  userId: widget.chatUserId,
                  username: _chatPartner != null 
                      ? _getPartnerDisplayName()
                      : widget.chatUsername,
                ),
              ),
            );
          },
          child: Row(
            children: [
              Stack(
                children: [
                  AvatarWithFrame(
                    user: _chatPartner,
                    radius: 20,
                    backgroundColor: theme.primaryColor.withOpacity(0.2),
                    textStyle: TextStyle(color: theme.primaryColor),
                  ),
                  if (_chatPartner?.isOnline == true)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.backgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _chatPartner != null 
                          ? _getPartnerDisplayName()
                          : widget.chatUsername,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_isTyping)
                      _buildTypingIndicator(theme)
                    else
                      Text(
                        _getLastSeenText(),
                        style: TextStyle(
                          fontSize: 12,
                          color: _chatPartner?.isOnline == true
                              ? Colors.green
                              : theme.secondaryTextColor,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
            ),
            actions: [
                IconButton(
                  icon: Icon(_showSearch ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _searchQuery = '';
                        _searchController.clear();
                      }
                    });
                  },
                ),
                PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: theme.bubbleColorOther,
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(
                        userId: widget.chatUserId,
                        username: _chatPartner != null 
                            ? _getPartnerDisplayName()
                            : widget.chatUsername,
                      ),
                    ),
                  );
                  break;
                case 'clear':
                  _showClearChatDialog(theme);
                  break;
                case 'media':
                  _showMediaGallery(theme);
                  break;
                case 'wallpaper':
                  _showWallpaperDialog(theme);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: theme.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Профиль',
                      style: TextStyle(color: theme.textColor),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'media',
                child: Row(
                  children: [
                    Icon(Icons.photo_library, color: theme.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Медиа',
                      style: TextStyle(color: theme.textColor),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'wallpaper',
                child: Row(
                  children: [
                    Icon(Icons.wallpaper, color: theme.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Обои',
                      style: TextStyle(color: theme.textColor),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Очистить чат',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
            ),
            ],
          ),
        ),
      ),
    ),
      body: Stack(
        children: [
          if (_wallpaperPath != null)
            Positioned.fill(
              child: _wallpaperBlurLevel > 0
                  ? ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: _wallpaperBlurLevel, sigmaY: _wallpaperBlurLevel),
                      child: ImageCacheConfig.wallpaperImage(
                        imageUrl: _wallpaperPath!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(color: theme.backgroundColor),
                        placeholder: (context, url) => Container(color: theme.backgroundColor),
                      ),
                    )
                  : ImageCacheConfig.wallpaperImage(
                      imageUrl: _wallpaperPath!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(color: theme.backgroundColor),
                      placeholder: (context, url) {
                        return Container(color: theme.backgroundColor);
                      },
                    ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.backgroundColor,
                    theme.backgroundColor.withOpacity(0.95),
                    theme.primaryColor.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          Positioned.fill(
            child: Stack(
              children: [
                Column(
                  children: [
                    if (_showSearch)
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: theme.backgroundColor,
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: theme.textColor),
                          decoration: InputDecoration(
                            hintText: 'Поиск по сообщениям...',
                            hintStyle: TextStyle(color: theme.secondaryTextColor),
                            prefixIcon: Icon(Icons.search, color: theme.secondaryTextColor),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: theme.secondaryTextColor),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: theme.bubbleColorOther,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => _searchQuery = value.toLowerCase());
                          },
                        ),
                      ),
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: _isLoadingMessages
                                  ? CircularProgressIndicator(
                                      color: theme.primaryColor,
                                    )
                                  : Text(
                                      'Начните общение',
                                      style: TextStyle(
                                        color: theme.secondaryTextColor,
                                        fontSize: 16,
                                      ),
                                    ),
                            )
                          : _buildMessagesList(theme),
                    ),
                  ],
                ),
                if (_replyingTo != null)
                  Positioned(
                    bottom: _showEmojiPicker ? 250 : 60,
                    left: 0,
                    right: 0,
                    child: _buildReplyPreview(theme),
                  ),
                _buildInputContainer(theme),
                
                if (_showEmojiPicker)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildEmojiPicker(theme),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showWallpaperDialog(AppTheme theme) {
    double tempBlurLevel = _wallpaperBlurLevel;
    
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.light 
                      ? Colors.white.withOpacity(0.7)
                      : theme.backgroundColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.brightness == Brightness.light
                        ? Colors.white.withOpacity(0.5)
                        : Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.wallpaper,
                            color: theme.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Обои чата',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.backgroundColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.secondaryTextColor.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final image = await _picker.pickImage(source: ImageSource.gallery);
                              if (image != null) {
                                final uploadResult = await _userService.uploadFile(image);
                                if (uploadResult['success'] == true) {
                                  final imageUrl = uploadResult['url'] as String;
                                  await _saveWallpaperSettings(imageUrl, tempBlurLevel);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                } else {
                                  _showError('Ошибка загрузки: ${uploadResult['error']}');
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image, color: theme.primaryColor, size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Выбрать из галереи',
                                    style: TextStyle(
                                      color: theme.textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_wallpaperPath != null)
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.backgroundColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              await _saveWallpaperSettings(null, 0.0);
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete, color: Colors.red, size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Удалить обои',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_wallpaperPath != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Уровень размытия: ${tempBlurLevel.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: tempBlurLevel,
                        min: 0.0,
                        max: 20.0,
                        divisions: 40,
                        label: tempBlurLevel.toStringAsFixed(1),
                        activeColor: theme.primaryColor,
                        inactiveColor: theme.secondaryTextColor.withOpacity(0.3),
                        onChanged: (value) {
                          setStateDialog(() {
                            tempBlurLevel = value;
                          });
                        },
                        onChangeEnd: (value) async {
                          await _saveWallpaperSettings(_wallpaperPath, value);
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.backgroundColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.secondaryTextColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Center(
                            child: Text(
                              'Закрыть',
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(AppTheme theme) {
    if (_replyingTo == null) return const SizedBox.shrink();
    
    final isReplyingToMe = _replyingTo!.senderId == _currentUserId;
    final replyText = _replyingTo!.messageType == 'image'
        ? '📷 Фото'
        : _replyingTo!.encryptedContent;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: theme.primaryColor,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            color: theme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'В ответ ${isReplyingToMe ? 'Вам' : (_chatPartner != null 
                      ? _getPartnerDisplayName()
                      : widget.chatUsername)}',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyText,
                  style: TextStyle(
                    color: theme.textColor.withOpacity(0.9),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _replyingTo = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                color: theme.secondaryTextColor,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputContainer(AppTheme theme) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: _showEmojiPicker ? 250 : 0,  
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: _inputPanelBlur, sigmaY: _inputPanelBlur),
          child: Container(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.light
                  ? Colors.white.withOpacity(_inputPanelOpacity)
                  : theme.backgroundColor.withOpacity(_inputPanelOpacity),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                      color: theme.secondaryTextColor,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _showEmojiPicker = !_showEmojiPicker;
                        if (_showEmojiPicker) {
                          _focusNode.unfocus();
                        } else {
                          _focusNode.requestFocus();
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      style: TextStyle(color: theme.textColor, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: _replyingTo != null ? 'Ответить...' : 'Сообщение',
                        hintStyle: TextStyle(color: theme.secondaryTextColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.attach_file, color: theme.secondaryTextColor, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _sendImage,
                  ),
                  const SizedBox(width: 4),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (context, value, child) {
                      final isEmpty = value.text.trim().isEmpty;
                      return IconButton(
                        icon: Icon(
                          Icons.send,
                          color: isEmpty ? theme.secondaryTextColor : theme.primaryColor,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: isEmpty ? null : _sendMessage,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiPicker(AppTheme theme) {
    final backgroundColor = theme.backgroundColor;
    
    return Container(
      height: 250,
      color: backgroundColor,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          setState(() {
            _messageController.text = _messageController.text + emoji.emoji;
          });
        },
        config: Config(
          height: 250,
          checkPlatformCompatibility: true,
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: backgroundColor,
            iconColorSelected: theme.primaryColor,
            iconColor: theme.primaryColor.withValues(alpha: 0.6),
            indicatorColor: theme.primaryColor,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: backgroundColor,
            buttonIconColor: theme.secondaryTextColor,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: backgroundColor,
            buttonColor: theme.primaryColor,
          ),
          emojiViewConfig: EmojiViewConfig(
            backgroundColor: backgroundColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList(AppTheme theme) {
    final List<ChatMessage> filteredMessages;
    if (_searchQuery.isEmpty) {
      filteredMessages = _messages;
    } else {
      final queryLower = _searchQuery.toLowerCase();
      filteredMessages = _messages.where((msg) {
        return msg.encryptedContent.toLowerCase().contains(queryLower);
      }).toList();
    }

    if (filteredMessages.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.secondaryTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Сообщения не найдены',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: false, 
      addAutomaticKeepAlives: false, 
      addRepaintBoundaries: true, 
      physics: const ClampingScrollPhysics(), 
      cacheExtent: 100, 
      itemExtent: null,
      key: const PageStorageKey('chat_messages'),
      padding: EdgeInsets.only(
        top: kToolbarHeight + MediaQuery.of(context).padding.top + 16, 
        bottom: _showEmojiPicker ? 350 : 100, 
        left: 16,
        right: 16,
      ),
      itemCount: filteredMessages.length,
      itemBuilder: (context, index) {
        if (index >= filteredMessages.length) return const SizedBox.shrink();
        
        final message = filteredMessages[index];
        final isMe = message.senderId == _currentUserId;
        
        return RepaintBoundary(
          key: ValueKey('message_${message.id}'),
          child: Padding(
          padding: EdgeInsets.only(
            bottom: 4,
            left: isMe ? 40 : 0,
            right: isMe ? 0 : 40,
          ),
          child: Dismissible(
            key: Key('msg_${message.id}_${index}'),
            direction: DismissDirection.horizontal,
            movementDuration: const Duration(milliseconds: 100),
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.copy, color: theme.primaryColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Копировать',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ответить',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.reply, color: Colors.green, size: 24),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                if (message.messageType == 'text') {
                  Clipboard.setData(ClipboardData(text: message.encryptedContent));
                }
              } else if (direction == DismissDirection.endToStart) {
                setState(() {
                  _replyingTo = message;
                });
                _focusNode.requestFocus();
              }
              return false;
            },
            child: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: MessageBubble(
                text: message.encryptedContent,
                isMe: isMe,
                isRead: message.isRead,
                theme: theme,
                timestamp: message.timestamp,
                messageType: message.messageType,
                mediaUrl: message.mediaUrl,
                index: index,
                replyToText: message.replyToText,
                replyToSenderName: message.replyToSenderName,
                cornerRadius: _cornerRadius,
                messageOpacity: _messageOpacity,
                messageBlur: _messageBlur,
                onReply: () {
                  setState(() {
                    _replyingTo = message;
                  });
                  _focusNode.requestFocus();
                },
                onDelete: isMe ? () => _deleteMessage(message) : null,
              ),
            ),
          ),
        ),
        );
      },
    );
  }

  Widget _buildTypingIndicator(AppTheme theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'печатает',
          style: TextStyle(
            fontSize: 12,
            color: theme.primaryColor,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 24,
          height: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return _TypingDot(
                delay: Duration(milliseconds: index * 200),
                color: theme.primaryColor,
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _TypingDot extends StatefulWidget {
  final Duration delay;
  final Color color;

  const _TypingDot({
    required this.delay,
    required this.color,
  });

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 4,
          height: 4 + (_animation.value * 6),
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

