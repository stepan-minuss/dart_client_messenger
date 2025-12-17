import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/app_theme.dart';
import '../services/theme_service.dart';
import '../services/user_service.dart';
import 'theme_customization_screen.dart';

class ThemeEditorScreen extends StatefulWidget {
  const ThemeEditorScreen({super.key});

  @override
  State<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends State<ThemeEditorScreen> {
  double _messageTextSize = 15.0;
  double _cornerRadius = 18.0;
  final _picker = ImagePicker();
  final _userService = UserService();
  String? _wallpaperUrl;
  double _wallpaperBlur = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCornerRadius();
    _loadWallpaper();
  }

  Future<void> _loadCornerRadius() async {
    final prefs = await SharedPreferences.getInstance();
    final radius = prefs.getDouble('message_corner_radius') ?? 18.0;
    setState(() {
      _cornerRadius = radius;
    });
  }

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    final wallpaper = prefs.getString('global_wallpaper');
    final blur = prefs.getDouble('global_wallpaper_blur') ?? 0.0;
    setState(() {
      _wallpaperUrl = wallpaper;
      _wallpaperBlur = blur;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.currentTheme;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Настройки темы'),
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChatPreview(theme),
            const SizedBox(height: 24),
            _buildSliderSection(
              theme,
              'Размер текста сообщений',
              _messageTextSize,
              10.0,
              20.0,
              (value) => setState(() => _messageTextSize = value),
            ),
            const SizedBox(height: 24),
            
            _buildSliderSection(
              theme,
              'Углы блоков с сообщениями',
              _cornerRadius,
              0.0,
              30.0,
              (value) {
                setState(() => _cornerRadius = value);
                _saveCornerRadius(value);
              },
            ),
            const SizedBox(height: 24),
            
            _buildThemePresets(themeService, theme),
            const SizedBox(height: 24),
            
            _buildUserThemes(themeService, theme),
            const SizedBox(height: 24),
            
            _buildAdditionalSettings(themeService, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPreview(AppTheme theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 400,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.backgroundColor,
              theme.backgroundColor.withOpacity(0.95),
              theme.primaryColor.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            if (_wallpaperUrl != null)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _wallpaperBlur > 0
                      ? ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(sigmaX: _wallpaperBlur, sigmaY: _wallpaperBlur),
                          child: CachedNetworkImage(
                            imageUrl: _wallpaperUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      theme.backgroundColor,
                                      theme.backgroundColor.withOpacity(0.95),
                                      theme.primaryColor.withOpacity(0.1),
                                    ],
                                  ),
                                ),
                              );
                            },
                            placeholder: (context, url) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      theme.backgroundColor,
                                      theme.backgroundColor.withOpacity(0.95),
                                      theme.primaryColor.withOpacity(0.1),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: _wallpaperUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.backgroundColor,
                                    theme.backgroundColor.withOpacity(0.95),
                                    theme.primaryColor.withOpacity(0.1),
                                  ],
                                ),
                              ),
                            );
                          },
                          placeholder: (context, url) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.backgroundColor,
                                    theme.backgroundColor.withOpacity(0.95),
                                    theme.primaryColor.withOpacity(0.1),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.backgroundColor.withOpacity(0.3),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.bubbleColorOther.withOpacity(0.3),
                          child: Text(
                            'С',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Степан',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'был(а) сегодня в 16:18',
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreviewMessage(
                      theme,
                      'Доброе утро! 👋',
                      false,
                      '22:45',
                      _cornerRadius,
                      _messageTextSize,
                    ),
                    const SizedBox(height: 8),
                    _buildPreviewMessage(
                      theme,
                      'Знаешь, который час?',
                      false,
                      '22:45',
                      _cornerRadius,
                      _messageTextSize,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildPreviewMessage(
                        theme,
                        'В Токио утро 😎',
                        true,
                        '23:00',
                        _cornerRadius,
                        _messageTextSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.light
                          ? Colors.white.withOpacity(0.6)
                          : theme.backgroundColor.withOpacity(0.4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.emoji_emotions, color: theme.secondaryTextColor, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Сообщение',
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Icon(Icons.attach_file, color: theme.secondaryTextColor, size: 24),
                        const SizedBox(width: 8),
                        Icon(Icons.send, color: theme.primaryColor, size: 24),
                      ],
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

  Widget _buildPreviewMessage(
    AppTheme theme,
    String text,
    bool isMe,
    String time,
    double cornerRadius,
    double textSize,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(cornerRadius),
        topRight: Radius.circular(cornerRadius),
        bottomLeft: isMe ? Radius.circular(cornerRadius) : Radius.zero,
        bottomRight: isMe ? Radius.zero : Radius.circular(cornerRadius),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: isMe
                ? LinearGradient(
                    colors: [
                      theme.bubbleColorMe.withOpacity(0.6),
                      theme.primaryColor.withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isMe ? null : theme.bubbleColorOther.withOpacity(0.6),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(cornerRadius),
              topRight: Radius.circular(cornerRadius),
              bottomLeft: isMe ? Radius.circular(cornerRadius) : Radius.zero,
              bottomRight: isMe ? Radius.zero : Radius.circular(cornerRadius),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    color: isMe ? Colors.white : theme.textColor,
                    fontSize: textSize,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                time,
                style: TextStyle(
                  color: isMe ? Colors.white70 : theme.secondaryTextColor,
                  fontSize: 10,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.done_all,
                  color: Colors.white70,
                  size: 12,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderSection(
    AppTheme theme,
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bubbleColorOther.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: theme.primaryColor,
            inactiveColor: theme.secondaryTextColor.withOpacity(0.3),
            onChanged: (newValue) {
              onChanged(newValue);
              if (title.contains('Углы')) {
                _saveCornerRadius(newValue);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveCornerRadius(double radius) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('message_corner_radius', radius);
  }

  Widget _buildThemePresets(ThemeService themeService, AppTheme currentTheme) {
    final presets = [
      {'name': 'Классическая', 'theme': AppTheme.light, 'color': Colors.blue},
      {'name': 'Тёмная', 'theme': AppTheme.cyberViolet, 'color': Colors.purple},
      {'name': 'Ночная', 'theme': AppTheme.matrix, 'color': Colors.green},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Цветовая тема',
          style: TextStyle(
            color: currentTheme.textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final preset = presets[index];
              final isSelected = currentTheme.name == preset['name'] as String;
              return GestureDetector(
                onTap: () {
                  themeService.setTheme(preset['theme'] as AppTheme);
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        (preset['color'] as Color).withOpacity(0.8),
                        Colors.black,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? preset['color'] as Color
                          : Colors.white.withOpacity(0.2),
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.circle,
                        color: preset['color'] as Color,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        preset['name'] as String,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Icon(
                          Icons.check_circle,
                          color: preset['color'] as Color,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildAdditionalSettings(ThemeService themeService, AppTheme theme) {
    return Column(
      children: [
        _buildSettingTile(
          theme,
          Icons.wallpaper,
          'Изменить обои',
          () {
            _showGlobalWallpaperDialog(theme);
          },
        ),
        const SizedBox(height: 8),
        _buildSettingTile(
          theme,
          Icons.palette,
          'Настройки темы',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ThemeCustomizationScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showGlobalWallpaperDialog(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    final currentWallpaper = prefs.getString('global_wallpaper');
    double tempBlurLevel = prefs.getDouble('global_wallpaper_blur') ?? 0.0;
    
    if (!mounted) return;
    
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
                            onTap: () async {
                              final image = await _picker.pickImage(source: ImageSource.gallery);
                              if (image != null && mounted) {
                                try {
                                  final uploadResult = await _userService.uploadFile(image);
                                  if (uploadResult['success'] == true) {
                                    final imageUrl = uploadResult['url'] as String;
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setString('global_wallpaper', imageUrl);
                                    await prefs.setDouble('global_wallpaper_blur', tempBlurLevel);
                                    if (mounted) {
                                      Navigator.pop(context);
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Ошибка: $e')),
                                    );
                                  }
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image, color: theme.primaryColor, size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Выбрать из галереи',
                                    style: TextStyle(
                                      color: theme.textColor,
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
                      if (currentWallpaper != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.secondaryTextColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            key: ValueKey<double>(tempBlurLevel), 
                            child: tempBlurLevel > 0
                                ? ImageFiltered(
                                    imageFilter: ui.ImageFilter.blur(sigmaX: tempBlurLevel, sigmaY: tempBlurLevel),
                                    child: CachedNetworkImage(
                                      imageUrl: currentWallpaper!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: theme.backgroundColor,
                                        child: Center(
                                          child: CircularProgressIndicator(color: theme.primaryColor),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: theme.backgroundColor,
                                        child: Icon(Icons.error, color: theme.secondaryTextColor),
                                      ),
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: currentWallpaper!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: theme.backgroundColor,
                                      child: Center(
                                        child: CircularProgressIndicator(color: theme.primaryColor),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: theme.backgroundColor,
                                      child: Icon(Icons.error, color: theme.secondaryTextColor),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: theme.backgroundColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.remove('global_wallpaper');
                                await prefs.remove('global_wallpaper_blur');
                                if (mounted) {
                                  setState(() {
                                    _wallpaperUrl = null;
                                    _wallpaperBlur = 0.0;
                                  });
                                  Navigator.pop(context);
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.delete, color: Colors.red, size: 24),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Удалить обои',
                                      style: TextStyle(
                                        color: Colors.red,
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
                            if (mounted) {
                              setState(() {
                                _wallpaperBlur = value;
                              });
                            }
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

  Future<void> _applyUserTheme(Map<String, dynamic> userTheme, ThemeService themeService) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final appTheme = AppTheme(
        name: userTheme['name'] as String? ?? 'Custom',
        primaryColor: Color(int.parse(userTheme['primary_color'] as String)),
        backgroundColor: Color(int.parse(userTheme['background_color'] as String)),
        bubbleColorMe: Color(int.parse(userTheme['bubble_color_me'] as String)),
        bubbleColorOther: Color(int.parse(userTheme['bubble_color_other'] as String)),
        textColor: Color(int.parse(userTheme['text_color'] as String)),
        secondaryTextColor: Color(int.parse(userTheme['secondary_text_color'] as String)),
        brightness: userTheme['brightness'] == 'dark' ? Brightness.dark : Brightness.light,
      );
      await themeService.setTheme(appTheme);
      final wallpaperUrl = userTheme['wallpaper_url'] as String?;
      final wallpaperBlur = double.tryParse(userTheme['wallpaper_blur'] as String? ?? '0.0') ?? 0.0;
      
      if (wallpaperUrl != null && wallpaperUrl.isNotEmpty) {
        await prefs.setString('global_wallpaper', wallpaperUrl);
        await prefs.setDouble('global_wallpaper_blur', wallpaperBlur);
      } else {
        await prefs.remove('global_wallpaper');
        await prefs.remove('global_wallpaper_blur');
      }
      final glassOpacity = prefs.getDouble('glass_opacity') ?? 0.3;
      final glassBlur = prefs.getDouble('glass_blur') ?? 10.0;
      final messageOpacity = prefs.getDouble('message_opacity') ?? 0.6;
      final messageBlur = prefs.getDouble('message_blur') ?? 15.0;
      final appBarOpacity = prefs.getDouble('appbar_opacity') ?? 0.3;
      final appBarBlur = prefs.getDouble('appbar_blur') ?? 10.0;
      final inputPanelOpacity = prefs.getDouble('input_panel_opacity') ?? 0.4;
      final inputPanelBlur = prefs.getDouble('input_panel_blur') ?? 15.0;
      await prefs.setDouble('glass_opacity', glassOpacity);
      await prefs.setDouble('glass_blur', glassBlur);
      await prefs.setDouble('message_opacity', messageOpacity);
      await prefs.setDouble('message_blur', messageBlur);
      await prefs.setDouble('appbar_opacity', appBarOpacity);
      await prefs.setDouble('appbar_blur', appBarBlur);
      await prefs.setDouble('input_panel_opacity', inputPanelOpacity);
      await prefs.setDouble('input_panel_blur', inputPanelBlur);
      
      if (mounted) {
        Navigator.pop(context); 
      }
    } catch (e) {
      print('Ошибка применения темы: $e');
    }
  }

  Widget _buildUserThemes(ThemeService themeService, AppTheme theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _userService.getUserThemes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final userThemes = snapshot.data!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Мои темы',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...userThemes.map((userTheme) {
              final themeName = userTheme['name'] as String? ?? 'Без названия';
              final themeId = userTheme['id'] as int;
              
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
                      await _applyUserTheme(userTheme, themeService);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(int.parse(userTheme['primary_color'] as String)),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              themeName,
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, color: theme.primaryColor, size: 20),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ThemeCustomizationScreen(existingTheme: userTheme),
                                ),
                              ).then((_) => setState(() {})); 
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () async {
                              final result = await _userService.deleteUserTheme(themeId);
                              if (result['success'] == true) {
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _userService.dispose();
    super.dispose();
  }

  Widget _buildSettingTile(
    AppTheme theme,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bubbleColorOther.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: theme.primaryColor, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
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
}
