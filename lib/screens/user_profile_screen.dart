import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../services/user_service.dart';
import '../services/theme_service.dart';
import '../models/app_theme.dart';
import '../utils/display_name_helper.dart';
import '../utils/image_cache_config.dart';
import 'chat_screen.dart';
import 'image_viewer_screen.dart';
import '../widgets/avatar_with_frame.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;
  final String username;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  final _userService = UserService();
  late TabController _tabController;
  User? _profileUser;
  List<Map<String, dynamic>> _sharedMedia = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _userService.getUserProfile(widget.userId);
      
      if (mounted) {
        setState(() {
          _profileUser = user;
          _isLoading = false;
        });
      }
      
      await _loadSharedMedia();
    } catch (e) {
      print('Ошибка загрузки профиля: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSharedMedia() async {
    try {
      final media = await _userService.getSharedMedia(widget.userId);
      if (mounted) {
        setState(() {
          _sharedMedia = media;
        });
      }
    } catch (e) {
      print('Ошибка загрузки медиа: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.currentTheme;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.backgroundColor.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: theme.textColor),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.primaryColor.withOpacity(0.15),
                      theme.backgroundColor,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.primaryColor.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: AvatarWithFrame(
                              user: _profileUser,
                              size: 96,
                              backgroundColor: theme.primaryColor.withOpacity(0.1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _profileUser != null
                              ? DisplayNameHelper.getDisplayNameWithoutContacts(_profileUser!)
                              : widget.username,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _profileUser?.isOnline == true
                                ? Colors.green.withOpacity(0.2)
                                : theme.bubbleColorOther.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _profileUser?.isOnline == true
                                  ? Colors.green.withOpacity(0.5)
                                  : theme.secondaryTextColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_profileUser?.isOnline == true)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (_profileUser?.isOnline == true)
                                const SizedBox(width: 6),
                              Text(
                                _getLastSeenText(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _profileUser?.isOnline == true
                                      ? Colors.green
                                      : theme.secondaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.backgroundColor.withOpacity(0.3),
                  border: Border(
                    bottom: BorderSide(
                      color: theme.secondaryTextColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: theme.primaryColor,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelColor: theme.primaryColor,
                      unselectedLabelColor: theme.secondaryTextColor,
                      labelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(text: 'Информация'),
                        Tab(text: 'Медиа'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInfoTab(theme),
                      _buildMediaTab(theme),
                    ],
                  ),
                ),
                _buildMessageButton(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab(AppTheme theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            theme: theme,
            title: 'О себе',
            content: _profileUser?.bio ?? 'Не указано',
            icon: Icons.info_outline,
            isEmpty: _profileUser?.bio == null || _profileUser!.bio!.isEmpty,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            theme: theme,
            title: 'Дата рождения',
            content: _profileUser?.birthdate != null
                ? _formatDate(_profileUser!.birthdate!)
                : 'Не указано',
            icon: Icons.cake_outlined,
            isEmpty: _profileUser?.birthdate == null,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required AppTheme theme,
    required String title,
    required String content,
    required IconData icon,
    required bool isEmpty,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: theme.bubbleColorOther.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.primaryColor.withOpacity(0.15),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: theme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content,
                      style: TextStyle(
                        color: isEmpty
                            ? theme.secondaryTextColor.withOpacity(0.7)
                            : theme.textColor,
                        fontSize: 15,
                        fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageButton(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.secondaryTextColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primaryColor,
                          theme.primaryColor.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatUserId: widget.userId,
                                chatUsername: widget.username,
                                onMessageSent: () {},
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.message, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Написать сообщение',
                                style: TextStyle(
                                  color: Colors.white,
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
                ),
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.bubbleColorOther.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _editLocalName(),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Icon(
                          Icons.person_add,
                          color: theme.primaryColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editLocalName() async {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.currentTheme;
    
    final controller = TextEditingController(text: _profileUser?.localName ?? '');
    
    final result = await showDialog<String>(
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
                  color: theme.primaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.text.isEmpty ? 'Добавить имя контакта' : 'Изменить имя контакта',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: TextField(
                        controller: controller,
                        style: TextStyle(color: theme.textColor),
                        decoration: InputDecoration(
                          hintText: 'Введите имя...',
                          hintStyle: TextStyle(color: theme.secondaryTextColor),
                          filled: true,
                          fillColor: theme.bubbleColorOther.withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        autofocus: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Отмена',
                          style: TextStyle(color: theme.secondaryTextColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.primaryColor,
                                theme.primaryColor.withOpacity(0.8),
                              ],
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                final name = controller.text.trim();
                                Navigator.pop(context, name.isEmpty ? null : name);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                child: Text(
                                  'Сохранить',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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
    
    if (result != null) {
      try {
        if (result.isEmpty) {
          await _userService.deleteContactLocalName(widget.userId);
        } else {
          await _userService.setContactLocalName(widget.userId, result);
        }
        
        await _loadProfile();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.isEmpty 
                  ? 'Локальное имя удалено' 
                  : 'Локальное имя сохранено'),
              backgroundColor: theme.bubbleColorOther,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  String _getLastSeenText() {
    if (_profileUser?.isOnline == true) {
      return 'в сети';
    }
    
    if (_profileUser?.lastSeen == null) {
      return 'был(а) недавно';
    }

    final now = DateTime.now();
    final lastSeen = _profileUser!.lastSeen!;
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'был(а) только что';
    } else if (difference.inMinutes < 60) {
      return 'был(а) ${difference.inMinutes} ${_pluralize(difference.inMinutes, 'минуту', 'минуты', 'минут')} назад';
    } else if (difference.inHours < 24) {
      if (now.day == lastSeen.day && now.month == lastSeen.month && now.year == lastSeen.year) {
        return 'был(а) сегодня в ${_formatTime(lastSeen)}';
      } else {
        final yesterday = now.subtract(const Duration(days: 1));
        if (yesterday.day == lastSeen.day && yesterday.month == lastSeen.month && yesterday.year == lastSeen.year) {
          return 'был(а) вчера в ${_formatTime(lastSeen)}';
        } else {
          return 'был(а) ${_formatDateTime(lastSeen)}';
        }
      }
    } else if (difference.inDays < 7) {
      return 'был(а) ${difference.inDays} ${_pluralize(difference.inDays, 'день', 'дня', 'дней')} назад в ${_formatTime(lastSeen)}';
    } else {
      return 'был(а) ${_formatDateTime(lastSeen)}';
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

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    
    if (date.year == now.year) {
      return '${date.day} ${months[date.month - 1]} в ${_formatTime(date)}';
    } else {
      return '${date.day} ${months[date.month - 1]} ${date.year} в ${_formatTime(date)}';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}.${date.month}.${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildMediaTab(AppTheme theme) {
    if (_sharedMedia.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.photo_library_outlined,
                    size: 48,
                    color: theme.primaryColor.withOpacity(0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Нет общих медиафайлов',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Отправляйте фото в чате',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: _sharedMedia.length,
      itemBuilder: (context, index) {
        final media = _sharedMedia[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ImageViewerScreen(
                  imageUrl: media['media_url'],
                ),
              ),
            );
          },
          child: Hero(
            tag: 'media_${media['id']}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageCacheConfig.messageMediaImage(
                      imageUrl: media['media_url'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          color: theme.secondaryTextColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.error_outline,
                          size: 24,
                          color: theme.secondaryTextColor,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
