import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../services/user_service.dart';
import '../services/theme_service.dart';
import '../models/app_theme.dart';
import '../widgets/avatar_with_frame.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _userService = UserService();
  final _picker = ImagePicker();
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _userService.getMe();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _isLoading = true);
      final result = await _userService.uploadAvatar(image);
      if (result['success'] == true) {
        await _loadProfile();
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showEditBioDialog(AppTheme theme) {
    final controller = TextEditingController(text: _currentUser?.bio ?? '');
    
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
                          Icons.info_outline,
                          color: theme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'О себе',
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    style: TextStyle(color: theme.textColor, fontSize: 16),
                    maxLines: 5,
                    minLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Расскажите о себе...',
                      hintStyle: TextStyle(color: theme.secondaryTextColor),
                      filled: true,
                      fillColor: theme.backgroundColor.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.secondaryTextColor.withOpacity(0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.secondaryTextColor.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    autofocus: true,
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
                          final bioText = controller.text.trim();
                          Navigator.pop(context);
                          setState(() => _isLoading = true);
                          try {
                            final result = await _userService.updateBio(bioText);
                            if (result['success'] == true && result['user'] != null) {
                              setState(() {
                                _currentUser = result['user'] as User;
                                _isLoading = false;
                              });
                            } else {
                              await _loadProfile();
                            }
                          } catch (e) {
                            setState(() => _isLoading = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Сохранить'),
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

  Future<void> _showEditBirthdateDialog(AppTheme theme) async {
    DateTime initialDate = DateTime.now().subtract(const Duration(days: 365 * 18));
    
    if (_currentUser?.birthdate != null && _currentUser!.birthdate!.isNotEmpty) {
      try {
        final parsedDate = DateTime.tryParse(_currentUser!.birthdate!);
        if (parsedDate != null) {
          initialDate = parsedDate;
        }
      } catch (e) {
      }
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: theme.brightness == Brightness.dark
                ? ColorScheme.dark(
                    primary: theme.primaryColor,
                    onPrimary: Colors.white,
                    surface: theme.backgroundColor,
                    onSurface: theme.textColor,
                  )
                : ColorScheme.light(
                    primary: theme.primaryColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: theme.textColor,
                  ),
            dialogBackgroundColor: theme.backgroundColor,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != initialDate) {
      setState(() => _isLoading = true);
      try {
        final dateString = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        final result = await _userService.updateBirthdate(dateString);
        if (result['success'] == true && result['user'] != null) {
          setState(() {
            _currentUser = result['user'] as User;
            _isLoading = false;
          });
        } else {
          await _loadProfile();
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка сохранения: $e')),
          );
        }
      }
    }
  }

  void _showEditUsernameDialog(AppTheme theme) {
    final controller = TextEditingController(text: _currentUser?.username ?? '');
    
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
                          Icons.alternate_email,
                          color: theme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Имя пользователя',
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    style: TextStyle(color: theme.textColor, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Введите username',
                      hintStyle: TextStyle(color: theme.secondaryTextColor),
                      prefixText: '@',
                      prefixStyle: TextStyle(color: theme.secondaryTextColor),
                      filled: true,
                      fillColor: theme.backgroundColor.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.secondaryTextColor.withOpacity(0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.secondaryTextColor.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    autofocus: true,
                    textInputAction: TextInputAction.done,
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
                          final newUsername = controller.text.trim();
                          if (newUsername.isEmpty) {
                            Navigator.pop(context);
                            return;
                          }
                          Navigator.pop(context);
                          setState(() => _isLoading = true);
                          try {
                            await _userService.updateUsername(newUsername);
                            await _loadProfile();
                          } catch (e) {
                            setState(() => _isLoading = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Сохранить'),
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

  void _showFrameSelectionDialog(AppTheme theme) {
    final frames = [
      {'id': 'none', 'name': 'Без рамки', 'icon': Icons.circle_outlined},
      {'id': 'rainbow', 'name': 'Радужная', 'icon': Icons.palette},
      {'id': 'fire', 'name': 'Огненная', 'icon': Icons.local_fire_department},
      {'id': 'purple', 'name': 'Фиолетовая', 'icon': Icons.circle},
    ];

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
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
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
                          Icons.border_color,
                          color: theme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Рамка аватара',
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ...frames.map((frame) {
                    final isSelected = _currentUser?.avatarFrame == frame['id'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: theme.bubbleColorOther.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            Navigator.pop(context);
                            setState(() => _isLoading = true);
                            try {
                              await _userService.updateAvatarFrame(frame['id'] as String);
                              await _loadProfile();
                            } catch (e) {
                              setState(() => _isLoading = false);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Row(
                              children: [
                                Icon(
                                  frame['icon'] as IconData,
                                  color: theme.primaryColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    frame['name'] as String,
                                    style: TextStyle(
                                      color: theme.textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: theme.primaryColor,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
    );
  }

  String _getBioDisplayText() {
    if (_currentUser?.bio == null) {
      return 'Не указано';
    }
    final bio = _currentUser!.bio!.trim();
    if (bio.isEmpty) {
      return 'Не указано';
    }
    return bio;
  }

  String _formatBirthdate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr.trim().isEmpty) {
      return 'Не указано';
    }
    try {
      final date = DateTime.tryParse(dateStr.trim());
      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
      }
      return 'Не указано';
    } catch (e) {
      print('Ошибка форматирования даты: $e, dateStr: $dateStr');
      return 'Не указано';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.currentTheme;

    if (_isLoading && _currentUser == null) {
      return Scaffold(
        backgroundColor: theme.backgroundColor,
        appBar: AppBar(
          title: const Text('Мой профиль'),
          backgroundColor: theme.backgroundColor,
          foregroundColor: theme.textColor,
        ),
        body: Center(
          child: CircularProgressIndicator(color: theme.primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Мой профиль'),
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FadeInDown(
              duration: const Duration(milliseconds: 500),
              child: Center(
                child: AvatarWithFrame(
                  user: _currentUser,
                  size: 120,
                  backgroundColor: theme.primaryColor.withOpacity(0.2),
                  showCameraIcon: true,
                  onCameraTap: _pickAndUploadAvatar,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: Column(
                children: [
                  _buildSettingItem(
                    theme: theme,
                    icon: Icons.info_outline,
                    title: 'О себе',
                    subtitle: _getBioDisplayText(),
                    onTap: () => _showEditBioDialog(theme),
                  ),
                  _buildSettingItem(
                    theme: theme,
                    icon: Icons.cake_outlined,
                    title: 'Дата рождения',
                    subtitle: _formatBirthdate(_currentUser?.birthdate),
                    onTap: () => _showEditBirthdateDialog(theme),
                  ),
                  _buildSettingItem(
                    theme: theme,
                    icon: Icons.alternate_email,
                    title: 'Имя пользователя',
                    subtitle: (_currentUser?.username != null && _currentUser!.username!.trim().isNotEmpty)
                        ? _currentUser!.username!
                        : 'Не указано',
                    onTap: () => _showEditUsernameDialog(theme),
                  ),
                  _buildSettingItem(
                    theme: theme,
                    icon: Icons.border_color,
                    title: 'Рамка аватара',
                    subtitle: _getFrameName(_currentUser?.avatarFrame),
                    onTap: () => _showFrameSelectionDialog(theme),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required AppTheme theme,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.bubbleColorOther.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: theme.primaryColor,
                    size: 24,
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
                          color: theme.textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 14,
                          ),
                          maxLines: title == 'О себе' ? 3 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.secondaryTextColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFrameName(String? frameId) {
    switch (frameId) {
      case 'rainbow':
        return 'Радужная';
      case 'fire':
        return 'Огненная';
      case 'purple':
        return 'Фиолетовая';
      default:
        return 'Без рамки';
    }
  }

  @override
  void dispose() {
    _userService.dispose();
    super.dispose();
  }
}

