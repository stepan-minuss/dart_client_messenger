import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/theme_service.dart';
import '../models/app_theme.dart';
import '../widgets/avatar_with_frame.dart';
import '../utils/image_cache_config.dart';
import 'theme_editor_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _userService = UserService();
  final _authService = AuthService();
  final _picker = ImagePicker();
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  String _formatBirthdate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}.${date.month}.${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _loadProfile() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        print('Токен отсутствует, перенаправляем на экран входа');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        return;
      }
      
      final user = await _userService.getMe();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Ошибка загрузки профиля в SettingsScreen: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        if (e.toString().contains('401') || e.toString().contains('истек') || e.toString().contains('отсутствует')) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
          });
        }
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

      print('Загружаем аватар: ${image.name}');
      final result = await _userService.uploadAvatar(image);
      print('Результат загрузки: $result');
      
      if (result['success'] == true) {
        await _loadProfile(); 
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Ошибка при загрузке аватара: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                          Navigator.pop(context);
                          setState(() => _isLoading = true);
                          try {
                            final bioText = controller.text.trim();
                            print('Сохранение bio: "$bioText"');
                            final result = await _userService.updateProfile(
                              bio: bioText.isEmpty ? null : bioText,
                            );
                            print('Результат сохранения: $result');
                            
                            if (mounted) {
                              if (result['success'] == true) {
                                if (result['user'] != null) {
                                  print('Обновляем профиль из ответа сервера');
                                  setState(() {
                                    _currentUser = result['user'] as User;
                                    _isLoading = false;
                                  });
                                } else {
                                  print('Данных нет в ответе, загружаем профиль заново');
                                  await _loadProfile();
                                }
                              } else {
                                setState(() => _isLoading = false);
                              }
                            }
                          } catch (e) {
                            print('Ошибка при сохранении bio: $e');
                            if (mounted) {
                              setState(() => _isLoading = false);
                            }
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

  void _showEditBirthdateDialog(AppTheme theme) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentUser?.birthdate != null 
          ? DateTime.tryParse(_currentUser!.birthdate!) ?? DateTime(2000)
          : DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: theme.primaryColor,
              surface: theme.backgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _isLoading = true);
      final dateString = picked.toIso8601String().split('T')[0];
      print('Сохранение birthdate: "$dateString"');
      try {
        final result = await _userService.updateProfile(birthdate: dateString);
        print('Результат сохранения: $result');
        
        if (mounted) {
          if (result['success'] == true) {
            if (result['user'] != null) {
              print('Обновляем профиль из ответа сервера');
              setState(() {
                _currentUser = result['user'] as User;
                _isLoading = false;
              });
            } else {
              print('Данных нет в ответе, загружаем профиль заново');
              await _loadProfile();
            }
          } else {
            setState(() => _isLoading = false);
          }
        }
      } catch (e) {
        print('Ошибка при сохранении birthdate: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showChangeUsernameDialog(AppTheme theme) {
    final controller = TextEditingController(text: _currentUser?.username);
    bool isChecking = false;
    bool isAvailable = true;
    String? errorMessage;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
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
                      color: Colors.white.withOpacity(0.2),
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
                              Icons.person,
                              color: theme.primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Изменить имя',
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      style: TextStyle(color: theme.textColor),
                      decoration: InputDecoration(
                        labelText: 'Новое имя',
                        labelStyle: TextStyle(color: theme.secondaryTextColor),
                        errorText: errorMessage,
                        suffixIcon: isChecking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        if (value.length < 3) {
                          setStateDialog(() {
                            errorMessage = 'Минимум 3 символа';
                            isAvailable = false;
                          });
                          return;
                        }
                        
                        setStateDialog(() {
                          isChecking = true;
                          errorMessage = null;
                        });
                        _userService.checkUsernameAvailability(value).then((available) {
                          if (context.mounted) {
                            setStateDialog(() {
                              isChecking = false;
                              isAvailable = available;
                              if (!available) {
                                errorMessage = 'Имя занято';
                              }
                            });
                          }
                        });
                      },
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
                            onPressed: isAvailable && !isChecking && controller.text.isNotEmpty
                                ? () async {
                                    Navigator.pop(context);
                                    setState(() => _isLoading = true);
                                    final result = await _userService.updateUsername(controller.text);
                                    
                                    if (mounted) {
                                      if (result['success'] == true) {
                                        await _loadProfile();
                                      } else {
                                        setState(() => _isLoading = false);
                                      }
                                    }
                                  }
                                : null,
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.currentTheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: theme.primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Настройки'),
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
                  Text(
                    _currentUser?.username ?? 'Пользователь',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSettingItem(
                    theme: theme,
                    icon: Icons.edit,
                    title: 'Изменить имя',
                    onTap: () => _showChangeUsernameDialog(theme),
                  ),
                  _buildSettingItem(
                    theme: theme,
                    icon: Icons.info_outline,
                    title: 'О себе',
                    subtitle: (_currentUser?.bio != null && _currentUser!.bio!.trim().isNotEmpty)
                        ? _currentUser!.bio!.trim()
                        : 'Не указано',
                    onTap: () => _showEditBioDialog(theme),
                  ),
                  _buildSettingItem(
                    theme: theme,
                    icon: Icons.cake_outlined,
                    title: 'Дата рождения',
                    subtitle: _currentUser?.birthdate ?? 'Не указано',
                    onTap: () => _showEditBirthdateDialog(theme),
                  ),
                  _buildSettingItem(
                    theme: theme,
                    icon: Icons.border_color,
                    title: 'Рамка аватара',
                    subtitle: _getFrameName(_currentUser?.avatarFrame),
                    onTap: () => _showFrameSelectionDialog(theme),
                  ),
                  _buildSettingItem(
                    theme: theme,
                    icon: Icons.wallpaper,
                    title: 'Обои',
                    subtitle: 'Глобальные обои для всех чатов',
                    onTap: () => _showGlobalWallpaperDialog(theme),
                  ),
                  const SizedBox(height: 24),
                  _buildSettingItem(
                    theme: theme,
                    icon: Icons.logout,
                    title: 'Выйти',
                    textColor: Colors.red,
                    onTap: () async {
                      await _authService.logout();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Версия приложения 1.0.0',
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 72, 
      decoration: BoxDecoration(
        color: theme.backgroundColor,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (textColor ?? theme.primaryColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: textColor ?? theme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor ?? theme.textColor,
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
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.secondaryTextColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getPlatformName() {
    if (kIsWeb) {
      return 'Web';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Android';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'iOS';
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'Windows';
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      return 'macOS';
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      return 'Linux';
    }
    return 'Unknown';
  }

  Widget _buildInfoRow(AppTheme theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: theme.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _getFrameName(String? frame) {
    if (frame == null || frame.isEmpty || frame == 'none') {
      return 'Без рамки';
    }
    final frameNames = {
      'gold': 'Золотая',
      'silver': 'Серебряная',
      'bronze': 'Бронзовая',
      'rainbow': 'Радужная',
      'blue': 'Синяя',
      'red': 'Красная',
      'green': 'Зеленая',
      'purple': 'Фиолетовая',
      'diamond': 'Алмазная',
    };
    return frameNames[frame] ?? frame;
  }

  Future<void> _showAvatarSelectionDialog(AppTheme theme) async {
    try {
      final avatars = await _userService.getAvatarsList();
      if (!mounted) return;

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
                  color: theme.backgroundColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                            Icons.image,
                            color: theme.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Выберите аватарку',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  Expanded(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: avatars.length,
                      itemBuilder: (context, index) {
                        final avatar = avatars[index];
                        final isSelected = _currentUser?.avatarUrl == avatar['url'];
                        return GestureDetector(
                          onTap: () async {
                            Navigator.pop(context);
                            setState(() => _isLoading = true);
                            try {
                              final result = await _userService.setPresetAvatar(avatar['id']);
                              if (result['success'] == true) {
                                await _loadProfile();
                                if (mounted) {
                                }
                              } else {
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(() => _isLoading = false);
                              }
                            }
                          },
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected 
                                        ? theme.primaryColor 
                                        : Colors.transparent,
                                    width: isSelected ? 3 : 0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: theme.primaryColor.withOpacity(0.5),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: ImageCacheConfig.avatarImage(
                                    imageUrl: avatar['url'],
                                    size: 120,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: theme.bubbleColorOther,
                                      child: const Center(child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: theme.bubbleColorOther,
                                      child: Icon(Icons.error, color: theme.secondaryTextColor),
                                    ),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor.withOpacity(0.2),
                          foregroundColor: theme.textColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Закрыть'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
      }
    }
  }

  Future<void> _showFrameSelectionDialog(AppTheme theme) async {
    try {
      final frames = await _userService.getAvatarFramesList();
      if (!mounted) return;

      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.backgroundColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: 450,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                            'Выберите рамку',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: frames.length,
                        itemBuilder: (context, index) {
                          final frame = frames[index];
                          final frameId = frame['id'] as String;
                          final isSelected = (_currentUser?.avatarFrame == frameId) || 
                                            (frameId == 'none' && (_currentUser?.avatarFrame == null || (_currentUser!.avatarFrame?.isEmpty ?? true)));
                          final previewUser = _currentUser != null
                              ? User(
                                  id: _currentUser!.id,
                                  username: _currentUser!.username,
                                  avatarUrl: _currentUser!.avatarUrl,
                                  avatarFrame: frameId == 'none' ? null : frameId,
                                )
                              : null;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? theme.primaryColor.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected
                                  ? Border.all(
                                      color: theme.primaryColor.withOpacity(0.5),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  Navigator.pop(context);
                                  setState(() => _isLoading = true);
                                  try {
                                    final result = await _userService.setAvatarFrame(frameId);
                                    if (result['success'] == true) {
                                      await _loadProfile();
                                      if (mounted) {
                                      }
                                    } else {
                                      if (mounted) {
                                        setState(() => _isLoading = false);
                                      }
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: Center(
                                          child: OverflowBox(
                                            maxWidth: 200,
                                            maxHeight: 200,
                                            alignment: Alignment.center,
                                            child: AvatarWithFrame(
                                              user: previewUser,
                                              size: 60,
                                              backgroundColor: theme.primaryColor.withOpacity(0.2),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          frame['name'] as String,
                                          style: TextStyle(
                                            color: isSelected ? theme.primaryColor : theme.textColor,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: theme.primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor.withOpacity(0.2),
                          foregroundColor: theme.textColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Закрыть'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
      }
    }
  }

  Color _getFrameColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  Future<void> _showGlobalWallpaperDialog(AppTheme theme) async {
    double tempBlurLevel = 0.0;
    String? tempWallpaperPath;
    final prefs = await SharedPreferences.getInstance();
    tempWallpaperPath = prefs.getString('global_wallpaper');
    tempBlurLevel = prefs.getDouble('global_wallpaper_blur') ?? 0.0;
    
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
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
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
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
                              Icons.wallpaper,
                              color: theme.primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Глобальные обои',
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final image = await _picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              final uploadResult = await _userService.uploadFile(image);
                              if (uploadResult['success'] == true) {
                                final imageUrl = uploadResult['url'] as String;
                                setStateDialog(() {
                                  tempWallpaperPath = imageUrl;
                                });
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('global_wallpaper', imageUrl);
                                if (context.mounted) {
                                }
                              } else {
                                if (context.mounted) {
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.image),
                          label: const Text('Выбрать из галереи'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (tempWallpaperPath != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.remove('global_wallpaper');
                              await prefs.setDouble('global_wallpaper_blur', 0.0);
                              setStateDialog(() {
                                tempWallpaperPath = null;
                                tempBlurLevel = 0.0;
                              });
                              if (context.mounted) {
                              }
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('Удалить обои'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      if (tempWallpaperPath != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Уровень размытия: ${tempBlurLevel.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: tempBlurLevel,
                          min: 0.0,
                          max: 20.0,
                          divisions: 40,
                          label: tempBlurLevel.toStringAsFixed(1),
                          activeColor: theme.primaryColor,
                          inactiveColor: theme.secondaryTextColor.withOpacity(0.3),
                          onChanged: (value) {
                            setStateDialog(() {
                              tempBlurLevel = value;
                            });
                          },
                          onChangeEnd: (value) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setDouble('global_wallpaper_blur', value);
                          },
                        ),
                      ],
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
        ),
      ),
    );
  }

  Widget _buildPreviewAvatar(AppTheme theme, String? frameId, String? avatarUrl, String username) {
    final frameColor = _getFrameColorFromId(frameId);
    final hasFrame = frameColor != Colors.transparent;

    return Container(
      width: 80,
      height: 80,
      decoration: hasFrame
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: frameColor,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: frameColor.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: CircleAvatar(
        radius: 36,
        backgroundColor: theme.primaryColor.withOpacity(0.2),
        backgroundImage: avatarUrl != null
            ? ImageCacheConfig.avatarImageProvider(avatarUrl)
            : null,
        child: avatarUrl == null
            ? Text(
                username[0].toUpperCase(),
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 28,
                ),
              )
            : null,
      ),
    );
  }

  Color _getFrameColorFromId(String? frameId) {
    if (frameId == null || frameId.isEmpty || frameId == 'none') {
      return Colors.transparent;
    }
    final frameColors = {
      'gold': const Color(0xFFFFD700),
      'silver': const Color(0xFFC0C0C0),
      'bronze': const Color(0xFFCD7F32),
      'rainbow': const Color(0xFFFF0000),
      'blue': const Color(0xFF0000FF),
      'red': const Color(0xFFFF0000),
      'green': const Color(0xFF00FF00),
      'purple': const Color(0xFF800080),
      'diamond': const Color(0xFFB9F2FF),
    };
    return frameColors[frameId] ?? Colors.transparent;
  }
}
