import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/theme_service.dart';
import '../services/security_service.dart';
import '../models/app_theme.dart';
import '../utils/jwt_helper.dart';
import '../utils/refresh_bus.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'theme_editor_screen.dart';
import 'user_search_screen.dart';
import 'profile_settings_screen.dart';
import 'security_settings_screen.dart';
import '../utils/display_name_helper.dart';
import '../services/contact_cache_service.dart';
import '../services/active_chats_cache_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'contacts_screen.dart';
import '../widgets/avatar_with_frame.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _userService = UserService();
  final _securityService = SecurityService();
  final _jwtHelper = JwtHelper();
  List<User> _users = [];
  bool _isLoading = true;
  User? _currentUser;
  bool _showAccountList = false;
  Map<String, Contact> _contactMap = {}; 

  @override
  void initState() {
    super.initState();
    _loadContactMap();
    _loadUsersFromCache(); 
    _loadUsers(); 
    _loadCurrentUser();
    RefreshBus.activeChatsVersion.addListener(_loadUsers);
  }
  
  Future<void> _loadUsersFromCache() async {
    try {
      final cachedUsers = await ActiveChatsCacheService().getCachedActiveChats();
      if (cachedUsers != null && cachedUsers.isNotEmpty && mounted) {
        setState(() {
          _users = cachedUsers;
          _isLoading = false;
        });
        print('Загружено ${cachedUsers.length} активных чатов из кэша');
      }
    } catch (e) {
      print('Ошибка загрузки активных чатов из кэша: $e');
    }
  }
  
  Future<void> _loadContactMap() async {
    try {
      final cachedMap = await ContactCacheService.getCachedContactMap();
      if (mounted && cachedMap.isNotEmpty) {
        setState(() {
          _contactMap = cachedMap;
        });
        print('Загружен кеш контактов: ${_contactMap.length} записей');
      }
      _updateContactMapInBackground();
    } catch (e) {
      print('Ошибка загрузки кеша контактов: $e');
    }
  }
  
  Future<void> _updateContactMapInBackground() async {
    try {
      final hasPermission = await FlutterContacts.requestPermission(readonly: true);
      if (!hasPermission) {
        return;
      }
      final deviceContacts = await FlutterContacts.getContacts(withProperties: true);
      final Map<String, Contact> contactMap = {};
      for (final contact in deviceContacts) {
        for (final phone in contact.phones) {
          final normalizedPhone = phone.number.replaceAll(RegExp(r'[^\d]'), '');
          if (normalizedPhone.isNotEmpty) {
            contactMap[normalizedPhone] = contact;
            if (normalizedPhone.length >= 10) {
              contactMap[normalizedPhone.substring(normalizedPhone.length - 10)] = contact;
            }
          }
        }
      }
      await ContactCacheService.cacheContactMap(contactMap);
      
      if (mounted) {
        setState(() {
          _contactMap = contactMap;
        });
      }
      
      print('Кеш контактов обновлен: ${contactMap.length} записей');
    } catch (e) {
      print('Ошибка обновления кеша контактов: $e');
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _userService.getMe();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      print('Ошибка загрузки текущего пользователя: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    RefreshBus.activeChatsVersion.removeListener(_loadUsers);
    _userService.dispose();
    _jwtHelper.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      print('Загрузка активных чатов...');
      final users = await _userService.getActiveChats();
      print('Загружено ${users.length} активных чатов');
      final decryptedUsers = <User>[];
      for (var user in users) {
        String? decryptedMessage;
        
        if (user.lastMessage != null && user.lastMessageType == 'text') {
          try {
            decryptedMessage = await _securityService.decryptMessage(user.lastMessage!);
            print('Расшифровано последнее сообщение для ${user.username}: $decryptedMessage');
          } catch (e) {
            print('Не удалось расшифровать последнее сообщение для ${user.username}: $e');
            decryptedMessage = 'Сообщение';
          }
        } else if (user.lastMessageType == 'image') {
          decryptedMessage = '📷 Фото';
        }
        
        decryptedUsers.add(User(
          id: user.id,
          username: user.username,
          firstName: user.firstName,
          lastName: user.lastName,
          phone: user.phone,
          publicKey: user.publicKey,
          avatarUrl: user.avatarUrl,
          bio: user.bio,
          birthdate: user.birthdate,
          lastSeen: user.lastSeen,
          isOnline: user.isOnline,
          lastMessage: decryptedMessage,
          lastMessageTime: user.lastMessageTime,
          lastMessageSenderId: user.lastMessageSenderId,
          lastMessageType: user.lastMessageType,
          localName: user.localName,
        ));
      }
      decryptedUsers.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });
      await ActiveChatsCacheService().cacheActiveChats(decryptedUsers);
      
      if (mounted) {
        setState(() {
          _users = decryptedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Ошибка загрузки активных чатов: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getDisplayName(User user) {
    Contact? deviceContact;
    if (user.phone != null && user.phone!.isNotEmpty) {
      final normalizedPhone = user.phone!.replaceAll(RegExp(r'[^\d]'), '');
      deviceContact = _contactMap[normalizedPhone];
      if (deviceContact == null && normalizedPhone.length >= 10) {
        deviceContact = _contactMap[normalizedPhone.substring(normalizedPhone.length - 10)];
      }
    }
    return DisplayNameHelper.getDisplayName(user, deviceContact: deviceContact);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now().toLocal();
    DateTime messageTime = time.isUtc ? time.toLocal() : time;
    if (messageTime.year == now.year && 
        messageTime.month == now.month && 
        messageTime.day == now.day) {
      return DateFormat('HH:mm').format(messageTime);
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (messageTime.year == yesterday.year && 
        messageTime.month == yesterday.month && 
        messageTime.day == yesterday.day) {
      return 'Вчера';
    }
    final weekAgo = now.subtract(const Duration(days: 7));
    if (messageTime.isAfter(weekAgo)) {
      return DateFormat('EEEE', 'ru').format(messageTime);
    }
    return DateFormat('dd.MM').format(messageTime);
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.currentTheme;

    return Scaffold(
      drawer: _buildDrawer(context, theme, themeService),
      appBar: AppBar(
        title: Text(
          _currentUser?.username ?? 'Nebula',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSearchScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.backgroundColor,
              theme.backgroundColor.withOpacity(0.8),
              theme.primaryColor.withOpacity(0.2),
            ],
          ),
        ),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: theme.primaryColor,
                ),
              )
            : _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: theme.secondaryTextColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нет активных чатов',
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Используйте поиск для начала переписки',
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Dismissible(
                        key: Key('chat_${user.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
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
                                    child: Padding(
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
                                                  'Удалить чат?',
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
                                          Text(
                                            'Чат с ${user.username} будет удален из списка',
                                            style: TextStyle(color: theme.secondaryTextColor),
                                          ),
                                          const SizedBox(height: 24),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
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
                                                onPressed: () => Navigator.pop(context, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                                child: const Text('Удалить'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ) ?? false;
                        },
                        onDismissed: (direction) {
                          setState(() {
                            _users.removeAt(index);
                          });
                        },
                        child: Container(
                          color: Colors.white.withOpacity(0.05),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            leading: Stack(
                              children: [
                                AvatarWithFrame(
                                  user: user,
                                  radius: 28,
                                  backgroundColor: theme.primaryColor.withOpacity(0.2),
                                  textStyle: TextStyle(color: theme.primaryColor, fontSize: 20),
                                ),
                                if (user.isOnline == true)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 14,
                                      height: 14,
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
                            title: Text(
                              _getDisplayName(user),
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: user.lastMessage != null
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      user.lastMessage!,
                                      style: TextStyle(
                                        color: theme.secondaryTextColor,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                                : null,
                            trailing: user.lastMessageTime != null
                                ? Text(
                                    _formatTime(user.lastMessageTime!),
                                    style: TextStyle(
                                      color: theme.secondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    chatUserId: user.id,
                                    chatUsername: _getDisplayName(user),
                                    onMessageSent: () {
                                      _loadUsers();
                                    },
                                  ),
                                ),
                              );
                              _loadUsers();
                            },
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: null, 
    );
  }

  Widget _buildDrawer(BuildContext context, AppTheme theme, ThemeService themeService) {
    return Drawer(
      backgroundColor: theme.backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: theme.backgroundColor,
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AvatarWithFrame(
                          user: _currentUser,
                          size: 50,
                          backgroundColor: theme.primaryColor.withOpacity(0.2),
                          showCameraIcon: false,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentUser?.firstName?.trim().isNotEmpty == true
                              ? _currentUser!.firstName!
                              : 'Пользователь',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                          ),
                        ),
                        if (_currentUser?.username != null && _currentUser!.username!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _currentUser!.username!,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: Icon(
                        theme.brightness == Brightness.light 
                            ? Icons.dark_mode 
                            : Icons.light_mode,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        themeService.toggleTheme();
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      icon: AnimatedRotation(
                        turns: _showAccountList ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_up,
                          color: theme.primaryColor,
                          size: 20,
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          _showAccountList = !_showAccountList;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_showAccountList) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Аккаунты',
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.add, color: theme.primaryColor, size: 20),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: AvatarWithFrame(
                  user: _currentUser,
                  size: 40,
                  backgroundColor: theme.primaryColor.withOpacity(0.2),
                  showCameraIcon: false,
                ),
                title: Text(
                  _currentUser?.firstName?.trim().isNotEmpty == true
                      ? _currentUser!.firstName!
                      : 'Пользователь',
                  style: TextStyle(color: theme.textColor),
                ),
                subtitle: _currentUser?.username != null && _currentUser!.username!.trim().isNotEmpty
                    ? Text(_currentUser!.username!, style: TextStyle(color: theme.secondaryTextColor))
                    : null,
              ),
              const Divider(),
            ],
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    context,
                    theme,
                    Icons.person,
                    'Мой профиль',
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    theme,
                    Icons.contacts,
                    'Контакты',
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContactsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    theme,
                    Icons.palette,
                    'Оформление',
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ThemeEditorScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    theme,
                    Icons.settings,
                    'Настройки',
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SecuritySettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  _buildDrawerItem(
                    context,
                    theme,
                    Icons.logout,
                    'Выйти',
                    () async {
                      Navigator.pop(context);
                      final authService = AuthService();
                      await authService.logout();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    textColor: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    AppTheme theme,
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? theme.primaryColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? theme.textColor,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showAccountSwitcher(BuildContext context, AppTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.secondaryTextColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Аккаунты',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.add, color: theme.primaryColor),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              leading: AvatarWithFrame(
                user: _currentUser,
                size: 40,
                backgroundColor: theme.primaryColor.withOpacity(0.2),
                showCameraIcon: false,
              ),
              title: Text(
                _currentUser?.firstName?.trim().isNotEmpty == true
                    ? _currentUser!.firstName!
                    : 'Пользователь',
                style: TextStyle(color: theme.textColor),
              ),
              subtitle: _currentUser?.username != null && _currentUser!.username!.trim().isNotEmpty
                  ? Text(_currentUser!.username!, style: TextStyle(color: theme.secondaryTextColor))
                  : null,
              trailing: Icon(Icons.check, color: theme.primaryColor),
            ),
            const Divider(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

