import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _requestAndroidPermissions();

    _initialized = true;
    print('Сервис уведомлений инициализирован');
  }

  static Future<void> _requestAndroidPermissions() async {
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  static Function(NotificationResponse)? onNotificationTapped;

  static void _onNotificationTapped(NotificationResponse response) {
    print('Уведомление нажато: actionId=${response.actionId}, payload=${response.payload}');
    onNotificationTapped?.call(response);
  }

  static Future<void> showMessageNotification({
    required int messageId,
    required String senderName,
    required String messageText,
    required int senderId,
    String? imageUrl,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    await _playNotificationSound();

    final replyAction = AndroidNotificationAction(
      'reply_action',
      'Ответить',
      titleColor: const Color(0xFF2196F3),
      showsUserInterface: true,
    );

    final androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Сообщения',
      channelDescription: 'Уведомления о новых сообщениях',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      actions: [replyAction],
      category: AndroidNotificationCategory.message,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'MESSAGE_CATEGORY',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationBody = messageText.length > 100 
        ? '${messageText.substring(0, 100)}...' 
        : messageText;

    final payload = '$senderId,$messageId';

    await _notifications.show(
      messageId,
      senderName,
      notificationBody,
      notificationDetails,
      payload: payload,
    );

    print('Показано уведомление для сообщения от $senderName');
  }

  static Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('notification_sound.mp3'), volume: 0.5);
    } catch (e) {
      print('Не удалось воспроизвести звук уведомления: $e');
    }
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  static Future<void> cancel(int notificationId) async {
    await _notifications.cancel(notificationId);
  }
}

