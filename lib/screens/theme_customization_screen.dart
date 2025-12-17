import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme.dart';
import '../services/theme_service.dart';
import '../services/user_service.dart';

class ThemeCustomizationScreen extends StatefulWidget {
  final Map<String, dynamic>? existingTheme;
  
  const ThemeCustomizationScreen({super.key, this.existingTheme});

  @override
  State<ThemeCustomizationScreen> createState() => _ThemeCustomizationScreenState();
}

class _ThemeCustomizationScreenState extends State<ThemeCustomizationScreen> {
  final _userService = UserService();
  final _picker = ImagePicker();
  final _themeNameController = TextEditingController();
  
  late AppTheme _currentCustomTheme;
  String? _wallpaperUrl;
  double _wallpaperBlur = 0.0;
  bool _isLoading = false;
  
  double _glassOpacity = 0.3;
  double _glassBlur = 10.0;
  double _messageOpacity = 0.6;
  double _messageBlur = 15.0;
  double _appBarOpacity = 0.3;
  double _appBarBlur = 10.0;
  double _inputPanelOpacity = 0.4;
  double _inputPanelBlur = 15.0;

  int? _editingThemeId;

  @override
  void initState() {
    super.initState();
    final themeService = Provider.of<ThemeService>(context, listen: false);
    
    if (widget.existingTheme != null) {
      _editingThemeId = widget.existingTheme!['id'] as int?;
      _themeNameController.text = widget.existingTheme!['name'] as String? ?? '';
      _currentCustomTheme = AppTheme(
        name: widget.existingTheme!['name'] as String? ?? 'Custom',
        primaryColor: Color(int.parse(widget.existingTheme!['primary_color'] as String)),
        backgroundColor: Color(int.parse(widget.existingTheme!['background_color'] as String)),
        bubbleColorMe: Color(int.parse(widget.existingTheme!['bubble_color_me'] as String)),
        bubbleColorOther: Color(int.parse(widget.existingTheme!['bubble_color_other'] as String)),
        textColor: Color(int.parse(widget.existingTheme!['text_color'] as String)),
        secondaryTextColor: Color(int.parse(widget.existingTheme!['secondary_text_color'] as String)),
        brightness: widget.existingTheme!['brightness'] == 'dark' ? Brightness.dark : Brightness.light,
      );
      _wallpaperUrl = widget.existingTheme!['wallpaper_url'] as String?;
      _wallpaperBlur = double.tryParse(widget.existingTheme!['wallpaper_blur'] as String? ?? '0.0') ?? 0.0;
    } else {
      _currentCustomTheme = themeService.currentTheme;
    }
    
    _loadWallpaper();
    
    if (widget.existingTheme != null) {
      _loadGlassSettings();
    }
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

  Future<void> _loadGlassSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _glassOpacity = prefs.getDouble('glass_opacity') ?? 0.3;
      _glassBlur = prefs.getDouble('glass_blur') ?? 10.0;
      _messageOpacity = prefs.getDouble('message_opacity') ?? 0.6;
      _messageBlur = prefs.getDouble('message_blur') ?? 15.0;
      _appBarOpacity = prefs.getDouble('appbar_opacity') ?? 0.3;
      _appBarBlur = prefs.getDouble('appbar_blur') ?? 10.0;
      _inputPanelOpacity = prefs.getDouble('input_panel_opacity') ?? 0.4;
      _inputPanelBlur = prefs.getDouble('input_panel_blur') ?? 15.0;
    });
  }

  @override
  void dispose() {
    _themeNameController.dispose();
    _userService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.currentTheme;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Кастомизация темы'),
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           
            _buildThemeNameInput(theme),
            const SizedBox(height: 16),
            
            _buildFullThemePreview(_currentCustomTheme),
            const SizedBox(height: 24),
            
            _buildColorSection(themeService, theme),
            const SizedBox(height: 24),
            
            _buildWallpaperSection(theme),
            const SizedBox(height: 24),
            
            _buildGlassEffectSection(theme),
            const SizedBox(height: 24),
            
            _buildSaveSection(themeService, theme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeNameInput(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bubbleColorOther.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Название темы',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _themeNameController,
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              hintText: 'Введите название темы...',
              hintStyle: TextStyle(color: theme.secondaryTextColor),
              filled: true,
              fillColor: theme.backgroundColor.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.secondaryTextColor.withOpacity(0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.secondaryTextColor.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullThemePreview(AppTheme previewTheme) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final currentTheme = themeService.currentTheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: currentTheme.bubbleColorOther.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: currentTheme.primaryColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Превью темы',
            style: TextStyle(
              color: previewTheme.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    previewTheme.backgroundColor,
                    previewTheme.backgroundColor.withOpacity(0.95),
                    previewTheme.primaryColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  if (_wallpaperUrl != null)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: _wallpaperBlur, sigmaY: _wallpaperBlur),
                          child: Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(_wallpaperUrl!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: _appBarBlur, sigmaY: _appBarBlur),
                        child: Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: previewTheme.backgroundColor.withOpacity(_appBarOpacity),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: previewTheme.primaryColor.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    'А',
                                    style: TextStyle(
                                      color: previewTheme.textColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                      'Пользователь',
                                      style: TextStyle(
                                        color: previewTheme.textColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'был(а) только что',
                                      style: TextStyle(
                                        color: previewTheme.secondaryTextColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.more_vert,
                                color: previewTheme.textColor,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    bottom: 60,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPreviewMessage(previewTheme, 'Привет! 👋', false),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildPreviewMessage(previewTheme, 'Привет!', true),
                          ),
                          const SizedBox(height: 8),
                          _buildPreviewMessage(previewTheme, 'Как дела?', false),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildPreviewMessage(previewTheme, 'Отлично, спасибо!', true),
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
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: _inputPanelBlur, sigmaY: _inputPanelBlur),
                        child: Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: previewTheme.brightness == Brightness.light
                                ? Colors.white.withOpacity(_inputPanelOpacity)
                                : previewTheme.backgroundColor.withOpacity(_inputPanelOpacity),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.emoji_emotions,
                                color: previewTheme.secondaryTextColor,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Сообщение',
                                  style: TextStyle(
                                    color: previewTheme.secondaryTextColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.attach_file,
                                color: previewTheme.secondaryTextColor,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: previewTheme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPreview(AppTheme theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 300,
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
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: _wallpaperBlur, sigmaY: _wallpaperBlur),
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(_wallpaperUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreviewMessage(theme, 'Привет! 👋', false),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildPreviewMessage(theme, 'Привет!', true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewMessage(AppTheme theme, String text, bool isMe) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: _messageBlur, sigmaY: _messageBlur),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe
                ? theme.primaryColor.withOpacity(_messageOpacity)
                : theme.bubbleColorOther.withOpacity(_messageOpacity),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isMe ? Colors.white : theme.textColor,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorSection(ThemeService themeService, AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bubbleColorOther.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Цвета',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildColorPicker(
            theme,
            'Основной цвет',
            _currentCustomTheme.primaryColor,
            (color) {
              setState(() {
                _currentCustomTheme = _currentCustomTheme.copyWith(primaryColor: color);
              });
            },
          ),
          const SizedBox(height: 12),
          _buildColorPicker(
            theme,
            'Фон',
            _currentCustomTheme.backgroundColor,
            (color) {
              setState(() {
                _currentCustomTheme = _currentCustomTheme.copyWith(backgroundColor: color);
              });
            },
          ),
          const SizedBox(height: 12),
          _buildColorPicker(
            theme,
            'Цвет текста',
            _currentCustomTheme.textColor,
            (color) {
              setState(() {
                _currentCustomTheme = _currentCustomTheme.copyWith(textColor: color);
              });
            },
          ),
          const SizedBox(height: 12),
          _buildColorPicker(
            theme,
            'Вторичный текст',
            _currentCustomTheme.secondaryTextColor,
            (color) {
              setState(() {
                _currentCustomTheme = _currentCustomTheme.copyWith(secondaryTextColor: color);
              });
            },
          ),
          const SizedBox(height: 12),
          _buildColorPicker(
            theme,
            'Мои сообщения',
            _currentCustomTheme.bubbleColorMe,
            (color) {
              setState(() {
                _currentCustomTheme = _currentCustomTheme.copyWith(bubbleColorMe: color);
              });
            },
          ),
          const SizedBox(height: 12),
          _buildColorPicker(
            theme,
            'Сообщения других',
            _currentCustomTheme.bubbleColorOther,
            (color) {
              setState(() {
                _currentCustomTheme = _currentCustomTheme.copyWith(bubbleColorOther: color);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(AppTheme theme, String label, Color currentColor, ValueChanged<Color> onColorChanged) {
    return InkWell(
      onTap: () => _showColorPickerDialog(theme, label, currentColor, onColorChanged),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.backgroundColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.secondaryTextColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPickerDialog(AppTheme theme, String label, Color currentColor, ValueChanged<Color> onColorChanged) {
    Color tempColor = currentColor;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
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
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Flexible(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.5,
                          ),
                          child: ColorPicker(
                            pickerColor: tempColor,
                            onColorChanged: (Color color) {
                              setState(() {
                                tempColor = color;
                              });
                            },
                            pickerAreaHeightPercent: 0.7,
                            displayThumbColor: true,
                            enableAlpha: false,
                            labelTypes: const [],
                            pickerAreaBorderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Отмена',
                              style: TextStyle(color: theme.secondaryTextColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            onColorChanged(tempColor);
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tempColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Применить'),
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
    );
  }

  Widget _buildWallpaperSection(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bubbleColorOther.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Обои',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final image = await _picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                setState(() => _isLoading = true);
                try {
                  final uploadResult = await _userService.uploadFile(image);
                  if (uploadResult['success'] == true) {
                    final imageUrl = uploadResult['url'] as String;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('global_wallpaper', imageUrl);
                    setState(() {
                      _wallpaperUrl = imageUrl;
                      _isLoading = false;
                    });
                  }
                } catch (e) {
                  setState(() => _isLoading = false);
                }
              }
            },
            icon: const Icon(Icons.image),
            label: const Text('Выбрать обои'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
          if (_wallpaperUrl != null) ...[
            const SizedBox(height: 12),
            Text(
              'Уровень размытия: ${_wallpaperBlur.toStringAsFixed(1)}',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 14,
              ),
            ),
            Slider(
              value: _wallpaperBlur,
              min: 0.0,
              max: 20.0,
              divisions: 40,
              activeColor: theme.primaryColor,
              onChanged: (value) async {
                setState(() => _wallpaperBlur = value);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('global_wallpaper_blur', value);
              },
            ),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('global_wallpaper');
                await prefs.remove('global_wallpaper_blur');
                setState(() {
                  _wallpaperUrl = null;
                  _wallpaperBlur = 0.0;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Удалить обои'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassEffectSection(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bubbleColorOther.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Эффект стекла',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildSlider(
            theme,
            'Общая прозрачность',
            _glassOpacity,
            0.0,
            1.0,
            (value) async {
              setState(() => _glassOpacity = value);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('glass_opacity', value);
            },
          ),
          const SizedBox(height: 12),

          _buildSlider(
            theme,
            'Общий блюр',
            _glassBlur,
            0.0,
            30.0,
            (value) async {
              setState(() => _glassBlur = value);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('glass_blur', value);
            },
          ),
          const SizedBox(height: 24),
          
          Text(
            'Сообщения',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildSlider(
            theme,
            'Прозрачность сообщений',
            _messageOpacity,
            0.0,
            1.0,
            (value) async {
              setState(() => _messageOpacity = value);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('message_opacity', value);
            },
          ),
          const SizedBox(height: 12),
          
          _buildSlider(
            theme,
            'Блюр сообщений',
            _messageBlur,
            0.0,
            30.0,
            (value) async {
              setState(() => _messageBlur = value);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('message_blur', value);
            },
          ),
          const SizedBox(height: 24),
          
          Text(
            'Верхняя панель',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildSlider(
            theme,
            'Прозрачность панели',
            _appBarOpacity,
            0.0,
            1.0,
            (value) async {
              setState(() => _appBarOpacity = value);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('appbar_opacity', value);
            },
          ),
          const SizedBox(height: 12),
          
          _buildSlider(
            theme,
            'Блюр панели',
            _appBarBlur,
            0.0,
            30.0,
            (value) async {
              setState(() => _appBarBlur = value);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('appbar_blur', value);
            },
          ),
          const SizedBox(height: 24),
          
          Text(
            'Панель ввода',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildSlider(
            theme,
            'Прозрачность панели',
            _inputPanelOpacity,
            0.0,
            1.0,
            (value) async {
              setState(() => _inputPanelOpacity = value);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('input_panel_opacity', value);
            },
          ),
          const SizedBox(height: 12),
          
          _buildSlider(
            theme,
            'Блюр панели',
            _inputPanelBlur,
            0.0,
            30.0,
            (value) async {
              setState(() => _inputPanelBlur = value);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('input_panel_blur', value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    AppTheme theme,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 14,
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt() * 10,
          activeColor: theme.primaryColor,
          inactiveColor: theme.secondaryTextColor.withOpacity(0.3),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSaveSection(ThemeService themeService, AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bubbleColorOther.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сохранить тему',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              if (_themeNameController.text.trim().isEmpty) {
                return;
              }
              
              setState(() => _isLoading = true);
              
              try {
                final customTheme = _currentCustomTheme.copyWith(
                  name: _themeNameController.text.trim(),
                );
                await themeService.setTheme(customTheme);
                
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('glass_opacity', _glassOpacity);
                await prefs.setDouble('glass_blur', _glassBlur);
                await prefs.setDouble('message_opacity', _messageOpacity);
                await prefs.setDouble('message_blur', _messageBlur);
                await prefs.setDouble('appbar_opacity', _appBarOpacity);
                await prefs.setDouble('appbar_blur', _appBarBlur);
                await prefs.setDouble('input_panel_opacity', _inputPanelOpacity);
                await prefs.setDouble('input_panel_blur', _inputPanelBlur);
                
                if (_wallpaperUrl != null) {
                  await prefs.setString('global_wallpaper', _wallpaperUrl!);
                  await prefs.setDouble('global_wallpaper_blur', _wallpaperBlur);
                } else {
                  await prefs.remove('global_wallpaper');
                  await prefs.remove('global_wallpaper_blur');
                }
                
                try {
                  final themeJson = customTheme.toJson();
                  Map<String, dynamic> result;
                  
                  if (_editingThemeId != null) {
                    result = await _userService.updateUserTheme(
                      themeId: _editingThemeId!,
                      name: _themeNameController.text.trim(),
                      primaryColor: themeJson['primaryColor'].toString(),
                      backgroundColor: themeJson['backgroundColor'].toString(),
                      bubbleColorMe: themeJson['bubbleColorMe'].toString(),
                      bubbleColorOther: themeJson['bubbleColorOther'].toString(),
                      textColor: themeJson['textColor'].toString(),
                      secondaryTextColor: themeJson['secondaryTextColor'].toString(),
                      brightness: themeJson['brightness'],
                      wallpaperUrl: _wallpaperUrl,
                      wallpaperBlur: _wallpaperBlur.toString(),
                    );
                  } else {
                    result = await _userService.saveUserTheme(
                      name: _themeNameController.text.trim(),
                      primaryColor: themeJson['primaryColor'].toString(),
                      backgroundColor: themeJson['backgroundColor'].toString(),
                      bubbleColorMe: themeJson['bubbleColorMe'].toString(),
                      bubbleColorOther: themeJson['bubbleColorOther'].toString(),
                      textColor: themeJson['textColor'].toString(),
                      secondaryTextColor: themeJson['secondaryTextColor'].toString(),
                      brightness: themeJson['brightness'],
                      wallpaperUrl: _wallpaperUrl,
                      wallpaperBlur: _wallpaperBlur.toString(),
                    );
                  }
                  
                  if (result['success'] != true) {
                    print('Ошибка сохранения темы на сервере: ${result['error']}');
                  } else {
                    print('Тема успешно сохранена');
                  }
                } catch (e) {
                  print('Ошибка сохранения темы на сервере: $e');
                }
                
                if (mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Text('Сохранить тему'),
          ),
        ],
      ),
    );
  }
}

