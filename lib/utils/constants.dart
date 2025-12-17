import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  static String get baseUrl {
      return 'https://';
  }
  
  static String get socketUrl {
    if (kIsWeb) {
      return 'wss://';
    } else {
      return 'wss://';
    }
  }
  
  static const String authTokenKey = 'auth_token';
  static const String publicKeyKey = 'public_key';
  static const String privateKeyKey = 'private_key';
  
  static const String eventSendMessage = 'send_message';
  static const String eventNewMessage = 'new_message';
  static const String eventTyping = 'typing';
  static const String eventMessageSent = 'message_sent';
  static const String eventError = 'error';
  
  static const String endpointRegister = '/auth/register';
  static const String endpointLogin = '/auth/login';
  static const String endpointUsers = '/users';
  static const String endpointKeysExchange = '/keys/exchange';
}


