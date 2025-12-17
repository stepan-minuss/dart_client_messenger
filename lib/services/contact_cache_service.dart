import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactCacheService {
  static const String _contactMapKey = 'device_contact_map';
  static const String _contactMapVersionKey = 'device_contact_map_version';
  static const int _currentVersion = 1;
  static const int _cacheMaxAgeDays = 1;

  static Contact _createSimpleContact({
    required String id,
    required String displayName,
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) {
    return Contact(
      id: id,
      displayName: displayName,
      name: Name(first: firstName, last: lastName),
      phones: [Phone(phoneNumber)],
    );
  }

  static Future<Map<String, Contact>> getCachedContactMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_contactMapKey);
      final version = prefs.getInt(_contactMapVersionKey) ?? 0;
      final lastUpdateStr = prefs.getString('${_contactMapKey}_timestamp');
      if (cacheData == null || version != _currentVersion) {
        return {};
      }
      
      if (lastUpdateStr != null) {
        final lastUpdate = DateTime.tryParse(lastUpdateStr);
        if (lastUpdate != null) {
          final age = DateTime.now().difference(lastUpdate);
          if (age.inDays > _cacheMaxAgeDays) {
            await clearCache();
            return {};
          }
        }
      }
      final Map<String, dynamic> data = jsonDecode(cacheData);
      final Map<String, Contact> contactMap = {};
      for (final entry in data.entries) {
        final phoneNumber = entry.key;
        final contactData = entry.value as Map<String, dynamic>;
        final phoneNumberStr = contactData['phone_number'] as String? ?? phoneNumber;
        final contact = _createSimpleContact(
          id: contactData['id'] as String? ?? '',
          displayName: contactData['display_name'] as String? ?? '',
          firstName: contactData['first_name'] as String? ?? '',
          lastName: contactData['last_name'] as String? ?? '',
          phoneNumber: phoneNumberStr,
        );
        
        contactMap[phoneNumber] = contact;
      }
      
      return contactMap;
    } catch (e) {
      print('Ошибка загрузки кеша контактов: $e');
      return {};
    }
  }

  static Future<void> cacheContactMap(Map<String, Contact> contactMap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {};
      for (final entry in contactMap.entries) {
        final phoneNumber = entry.key;
        final contact = entry.value;
        
        data[phoneNumber] = {
          'id': contact.id,
          'display_name': contact.displayName,
          'first_name': contact.name.first,
          'last_name': contact.name.last,
          'phone_number': contact.phones.isNotEmpty ? contact.phones.first.number : phoneNumber,
        };
      }
      
      await prefs.setString(_contactMapKey, jsonEncode(data));
      await prefs.setInt(_contactMapVersionKey, _currentVersion);
      await prefs.setString('${_contactMapKey}_timestamp', DateTime.now().toIso8601String());
      
      print('Кеш контактов сохранен (${contactMap.length} записей)');
    } catch (e) {
      print('Ошибка сохранения кеша контактов: $e');
    }
  }

  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_contactMapKey);
      await prefs.remove(_contactMapVersionKey);
      await prefs.remove('${_contactMapKey}_timestamp');
      print('Кеш контактов очищен');
    } catch (e) {
      print('Ошибка очистки кеша контактов: $e');
    }
  }
}

