import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/theme_service.dart';
import '../services/user_service.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _userService = UserService();
  List<Contact> _deviceContacts = [];
  List<User> _registeredUsers = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      bool permissionGranted = false;
      try {
        print('Проверка разрешения на доступ к контактам...');
        permissionGranted = await FlutterContacts.requestPermission(readonly: true);
        print('Результат запроса разрешения: $permissionGranted');
      } catch (e) {
        print('Ошибка запроса разрешения: $e');
      }
      
      if (!permissionGranted) {
        print('Разрешение на доступ к контактам не предоставлено');
        if (mounted) {
          setState(() {
            _hasPermission = false;
            _isLoading = false;
          });
        }
        return;
      }
      
      print('Разрешение получено, загружаем контакты...');
      final registeredUsers = await _userService.getUsers();
      List<Contact> deviceContacts = [];
      try {
        print('Получение списка контактов...');
        deviceContacts = await FlutterContacts.getContacts(withProperties: true);
        print('Получено контактов: ${deviceContacts.length}');
        setState(() {
          _hasPermission = true;
        });
      } catch (e) {
        print('Ошибка доступа к контактам: $e');
        if (mounted) {
          setState(() {
            _hasPermission = false;
            _isLoading = false;
          });
        }
        return;
      }
      final registeredPhones = registeredUsers
          .where((u) => u.phone != null && u.phone!.isNotEmpty)
          .map((u) => u.phone!.replaceAll(RegExp(r'[^\d]'), ''))
          .toSet();
      
      print('Зарегистрированных номеров: ${registeredPhones.length}');
      print('Все зарегистрированные номера: ${registeredPhones.join(", ")}');
      final registeredLast10 = registeredPhones
          .where((phone) => phone.length >= 10)
          .map((phone) => phone.substring(phone.length - 10))
          .toSet();
      
      print('Уникальных последних 10 цифр: ${registeredLast10.length}');
      print('Примеры последних 10 цифр: ${registeredLast10.take(5).join(", ")}');
      
      final matchedContacts = deviceContacts.where((contact) {
        if (contact.phones.isEmpty) return false;
        for (var phoneItem in contact.phones) {
          var normalizedPhone = phoneItem.number.replaceAll(RegExp(r'[^\d]'), '');
          
          if (normalizedPhone.isEmpty) continue;
          
          print('Проверяем контакт "${contact.displayName}": номер "$normalizedPhone" (исходный: "${phoneItem.number}")');
          if (registeredPhones.contains(normalizedPhone)) {
            print('Найден контакт (точное совпадение): ${contact.displayName} -> $normalizedPhone');
            return true;
          }
          if (normalizedPhone.length >= 10) {
            final last10Digits = normalizedPhone.substring(normalizedPhone.length - 10);
            if (registeredLast10.contains(last10Digits)) {
              print('Найден контакт (частичное совпадение, последние 10): ${contact.displayName} -> $normalizedPhone (последние 10: $last10Digits)');
              return true;
            }
            if (normalizedPhone.startsWith('7') || normalizedPhone.startsWith('8')) {
              final withoutFirst = normalizedPhone.substring(1);
              if (registeredPhones.contains(withoutFirst)) {
                print('Найден контакт (без первого символа 7/8): ${contact.displayName} -> $normalizedPhone (без префикса: $withoutFirst)');
                return true;
              }
              if (registeredPhones.contains('7$withoutFirst') || registeredPhones.contains('8$withoutFirst')) {
                print('Найден контакт (с префиксом 7/8): ${contact.displayName} -> $normalizedPhone');
                return true;
              }
            }
            if (normalizedPhone.length >= 9) {
              final last9Digits = normalizedPhone.substring(normalizedPhone.length - 9);
              final found9 = registeredPhones.any((regPhone) {
                if (regPhone.length >= 9) {
                  final regLast9 = regPhone.substring(regPhone.length - 9);
                  return regLast9 == last9Digits;
                }
                return false;
              });
              
              if (found9) {
                print('Найден контакт (частичное совпадение, последние 9): ${contact.displayName} -> $normalizedPhone (последние 9: $last9Digits)');
                return true;
              }
            }
          } else if (normalizedPhone.length >= 9) {
            final found = registeredPhones.any((regPhone) {
              if (regPhone.length >= 9) {
                final regLast9 = regPhone.substring(regPhone.length - 9);
                final contactLast9 = normalizedPhone.substring(normalizedPhone.length - 9);
                return regLast9 == contactLast9;
              }
              return false;
            });
            
            if (found) {
              print('Найден контакт (короткий номер, последние 9): ${contact.displayName} -> $normalizedPhone');
              return true;
            }
          }
          if (normalizedPhone.length > 10) {
            final withoutFirst = normalizedPhone.substring(1);
            if (registeredPhones.contains(withoutFirst)) {
              print('Найден контакт (без первого символа): ${contact.displayName} -> $normalizedPhone (без префикса: $withoutFirst)');
              return true;
            }
          }
          
          print('Не найдено совпадение для "${contact.displayName}": $normalizedPhone');
        }
        return false;
      }).toList();
      
      print('Всего найдено совпадений: ${matchedContacts.length}');
      
      if (mounted) {
        setState(() {
          _deviceContacts = matchedContacts;
          _registeredUsers = registeredUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Ошибка загрузки контактов: $e');
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
      }
    }
  }

  User? _findUserByContact(Contact contact) {
    if (contact.phones.isEmpty) return null;
    for (var phoneItem in contact.phones) {
      var normalizedPhone = phoneItem.number.replaceAll(RegExp(r'[^\d]'), '');
      if (normalizedPhone.isEmpty) continue;
      
      print('Поиск пользователя для контакта "${contact.displayName}": номер "$normalizedPhone"');
      try {
        final user = _registeredUsers.firstWhere(
          (user) {
            if (user.phone == null || user.phone!.isEmpty) return false;
            final userPhone = user.phone!.replaceAll(RegExp(r'[^\d]'), '');
            return userPhone == normalizedPhone;
          },
        );
        print('Найден пользователь (точное совпадение): ${user.username} (ID: ${user.id})');
        return user;
      } catch (e) {
        if (normalizedPhone.length >= 10) {
          final last10Digits = normalizedPhone.substring(normalizedPhone.length - 10);
          try {
            final user = _registeredUsers.firstWhere(
              (user) {
                if (user.phone == null || user.phone!.isEmpty) return false;
                final userPhone = user.phone!.replaceAll(RegExp(r'[^\d]'), '');
                if (userPhone.length >= 10) {
                  final userLast10 = userPhone.substring(userPhone.length - 10);
                  return userLast10 == last10Digits;
                }
                return false;
              },
            );
            print('Найден пользователь (частичное совпадение, последние 10): ${user.username} (ID: ${user.id})');
            return user;
          } catch (e2) {
            if (normalizedPhone.length > 10) {
              final withoutFirst = normalizedPhone.substring(1);
              try {
                final user = _registeredUsers.firstWhere(
                  (user) {
                    if (user.phone == null || user.phone!.isEmpty) return false;
                    final userPhone = user.phone!.replaceAll(RegExp(r'[^\d]'), '');
                    return userPhone == withoutFirst;
                  },
                );
                print('Найден пользователь (без первого символа): ${user.username} (ID: ${user.id})');
                return user;
              } catch (e3) {
                continue;
              }
            }
            continue;
          }
        }
        continue;
      }
    }
    
    print('Не найден пользователь для контакта "${contact.displayName}"');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.currentTheme;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Контакты'),
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: theme.primaryColor),
            )
          : !_hasPermission
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.contacts_outlined,
                        size: 64,
                        color: theme.secondaryTextColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Нет доступа к контактам',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Разрешите доступ к контактам в настройках',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadContacts,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _deviceContacts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.contacts_outlined,
                            size: 64,
                            color: theme.secondaryTextColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Нет контактов',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'В вашей телефонной книге нет\nзарегистрированных пользователей',
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _deviceContacts.length,
                      itemBuilder: (context, index) {
                        final contact = _deviceContacts[index];
                        final user = _findUserByContact(contact);
                        
                        if (user == null || user.id == 0) {
                          return const SizedBox.shrink();
                        }
                        
                        final displayName = contact.displayName.isNotEmpty 
                            ? contact.displayName
                            : (contact.name.first.isNotEmpty || contact.name.last.isNotEmpty
                                ? '${contact.name.first} ${contact.name.last}'.trim()
                                : 'Без имени');
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: theme.bubbleColorOther.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.primaryColor.withOpacity(0.2),
                              child: Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              displayName,
                              style: TextStyle(
                                color: theme.textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              user.username.isNotEmpty ? '@${user.username}' : user.phone ?? '',
                              style: TextStyle(
                                color: theme.secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chat_bubble_outline,
                              color: theme.primaryColor,
                              size: 20,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    chatUserId: user.id,
                                    chatUsername: displayName,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }

  @override
  void dispose() {
    _userService.dispose();
    super.dispose();
  }
}

