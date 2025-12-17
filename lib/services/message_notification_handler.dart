import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../services/security_service.dart';
import '../utils/display_name_helper.dart';
import '../utils/jwt_helper.dart';
import 'socket_service.dart';
import 'open_chat_tracker.dart';

class MessageNotificationHandler {
  static final UserService _userService = UserService();
  static final SecurityService _securityService = SecurityService();
  static final JwtHelper _jwtHelper = JwtHelper();
  
  static Future<void> handleIncomingMessage(ChatMessage message) async {
    final currentUserId = await _jwtHelper.getCurrentUserId();
    if (currentUserId == null) {
      return; 
    }
    
    if (message.receiverId != currentUserId) {
      return;
    }
    
    if (message.senderId == currentUserId) {
      return; 
    }
    
    if (OpenChatTracker.isChatOpen(message.senderId)) {
      print('Чат с пользователем ${message.senderId} открыт, уведомление не показываем');
      return; 
    }
    
    try {
      final sender = await _userService.getUserProfile(message.senderId);
      final senderName = DisplayNameHelper.getDisplayNameWithoutContacts(sender);
      
      String notificationText;
      if (message.messageType == 'image') {
        notificationText = '📷 Фото';
      } else {
        try {
          notificationText = await _securityService.decryptMessage(message.encryptedContent);
        } catch (e) {
          notificationText = 'Сообщение';
        }
      }
      
      await NotificationService.showMessageNotification(
        messageId: message.id,
        senderName: senderName,
        messageText: notificationText,
        senderId: message.senderId,
        imageUrl: message.mediaUrl,
      );
    } catch (e) {
      print('Ошибка показа уведомления: $e');
    }
  }
}

