import '../services/user_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/auth_service.dart';
import '../utils/jwt_helper.dart';

class DisplayNameHelper {
  static String getDisplayName(
    User user, {
    Contact? deviceContact,
  }) {
    if (user.localName != null && user.localName!.trim().isNotEmpty) {
      return user.localName!.trim();
    }

    if (deviceContact != null) {
      final displayName = deviceContact.displayName.isNotEmpty
          ? deviceContact.displayName
          : (deviceContact.name.first.isNotEmpty || deviceContact.name.last.isNotEmpty
              ? '${deviceContact.name.first} ${deviceContact.name.last}'.trim()
              : null);
      if (displayName != null && displayName.isNotEmpty) {
        return displayName;
      }
    }

    if (user.firstName != null || user.lastName != null) {
      final fullName = '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();
      if (fullName.isNotEmpty) {
        return fullName;
      }
    }

    if (user.username != null && user.username!.trim().isNotEmpty) {
      return user.username!.trim();
    }

    return 'Пользователь';
  }

  static String getDisplayNameWithoutContacts(User user) {
    if (user.localName != null && user.localName!.trim().isNotEmpty) {
      return user.localName!.trim();
    }

    if (user.firstName != null || user.lastName != null) {
      final fullName = '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();
      if (fullName.isNotEmpty) {
        return fullName;
      }
    }

    if (user.username != null && user.username!.trim().isNotEmpty) {
      return user.username!.trim();
    }

    return 'Пользователь';
  }
}

