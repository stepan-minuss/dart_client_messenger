import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  final _storage = const FlutterSecureStorage();
  static const String _publicKeyKey = 'public_key';
  static const String _privateKeyKey = 'private_key';

  Future<Map<String, String>> generateKeyPair() async {
    final random = Random.secure();
    final publicKeyData = List<int>.generate(256, (_) => random.nextInt(256));
    final privateKeyData = List<int>.generate(512, (_) => random.nextInt(256));
    
    final publicKeyBase64 = base64Encode(publicKeyData);
    final privateKeyBase64 = base64Encode(privateKeyData);
    
    final publicKeyPem = _formatPemKey(publicKeyBase64, 'PUBLIC KEY');
    final privateKeyPem = _formatPemKey(privateKeyBase64, 'RSA PRIVATE KEY');
    
    await _storage.write(key: _publicKeyKey, value: publicKeyPem);
    await _storage.write(key: _privateKeyKey, value: privateKeyPem);
    
    return {
      'public_key': publicKeyPem,
      'private_key': privateKeyPem,
    };
  }

  String _formatPemKey(String base64Key, String keyType) {
    final chunks = <String>[];
    for (int i = 0; i < base64Key.length; i += 64) {
      chunks.add(base64Key.substring(
        i,
        (i + 64 < base64Key.length) ? i + 64 : base64Key.length,
      ));
    }
    return '-----BEGIN $keyType-----\n${chunks.join('\n')}\n-----END $keyType-----';
  }

  Future<String?> getPublicKey() async {
    return await _storage.read(key: _publicKeyKey);
  }

  Future<String?> getPrivateKey() async {
    return await _storage.read(key: _privateKeyKey);
  }

  Future<bool> hasKeys() async {
    final publicKey = await getPublicKey();
    return publicKey != null && publicKey.isNotEmpty;
  }

  Future<String> encryptMessage(String message, String recipientPublicKey) async {
    try {
      final key = encrypt.Key.fromSecureRandom(32);
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      
      final encrypted = encrypter.encrypt(message, iv: iv);
      
      final combined = {
        'data': encrypted.base64,
        'key': key.base64,
        'iv': iv.base64,
      };
      
      return base64Encode(utf8.encode(jsonEncode(combined)));
    } catch (e) {
      return base64Encode(utf8.encode(message));
    }
  }

  Future<String> decryptMessage(String encryptedMessage) async {
    try {
      final decoded = utf8.decode(base64Decode(encryptedMessage));
      final data = jsonDecode(decoded) as Map<String, dynamic>;
      
      final encryptedData = encrypt.Encrypted.fromBase64(data['data'] as String);
      final key = encrypt.Key.fromBase64(data['key'] as String);
      final iv = encrypt.IV.fromBase64(data['iv'] as String);
      
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt(encryptedData, iv: iv);
    } catch (e) {
      try {
        return utf8.decode(base64Decode(encryptedMessage));
      } catch (_) {
        return '[Не удалось расшифровать сообщение]';
      }
    }
  }
}
