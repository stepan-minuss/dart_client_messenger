import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import '../services/user_service.dart';
import '../services/theme_service.dart';
import '../models/app_theme.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _userService = UserService();
  
  String _avatarVisibility = 'all';
  List<int> _avatarVisibilityExceptions = [];
  bool _showReadReceipts = true;
  bool _showLastSeen = true;
  bool _showOnlineStatus = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final result = await _userService.getPrivacySettings();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        setState(() {
          _avatarVisibility = data['avatar_visibility'] ?? 'all';
          _showReadReceipts = data['show_read_receipts'] ?? true;
          _showLastSeen = data['show_last_seen'] ?? true;
          _showOnlineStatus = data['show_online_status'] ?? true;
          if (data['avatar_visibility_exceptions'] != null) {
            try {
              _avatarVisibilityExceptions = List<int>.from(
                jsonDecode(data['avatar_visibility_exceptions']) ?? []
              );
            } catch (e) {
              _avatarVisibilityExceptions = [];
            }
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePrivacySettings() async {
    try {
      final result = await _userService.updatePrivacySettings(
        avatarVisibility: _avatarVisibility,
        avatarVisibilityExceptions: _avatarVisibilityExceptions,
        showReadReceipts: _showReadReceipts,
        showLastSeen: _showLastSeen,
        showOnlineStatus: _showOnlineStatus,
      );
      
      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Настройки сохранены')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.currentTheme;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Конфиденциальность'),
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
        actions: [
          TextButton(
            onPressed: _savePrivacySettings,
            child: Text(
              'Сохранить',
              style: TextStyle(color: theme.primaryColor),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Видимость аватара',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildAvatarVisibilityOption(theme, 'all', 'Все', 'Аватар видят все пользователи'),
                  const SizedBox(height: 8),
                  _buildAvatarVisibilityOption(theme, 'contacts', 'Только контакты', 'Аватар видят только пользователи из вашей телефонной книги'),
                  const SizedBox(height: 8),
                  _buildAvatarVisibilityOption(theme, 'nobody', 'Никто', 'Аватар скрыт от всех пользователей'),
                  const SizedBox(height: 8),
                  _buildAvatarVisibilityOption(theme, 'except', 'Все, кроме...', 'Аватар скрыт от выбранных пользователей'),
                  if (_avatarVisibility == 'except') ...[
                    const SizedBox(height: 16),
                    _buildExceptionsList(theme),
                  ],
                  
                  const SizedBox(height: 24),
                  Text(
                    'Статус прочтения',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSwitchOption(
                    theme,
                    'Показывать статус прочтения',
                    'Другие пользователи будут видеть, когда вы прочитали их сообщения',
                    _showReadReceipts,
                    (value) => setState(() => _showReadReceipts = value),
                  ),
                  
                  const SizedBox(height: 24),
                  Text(
                    'Время последнего посещения',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSwitchOption(
                    theme,
                    'Показывать время последнего посещения',
                    'Другие пользователи будут видеть, когда вы были в сети последний раз',
                    _showLastSeen,
                    (value) => setState(() => _showLastSeen = value),
                  ),
                  
                  const SizedBox(height: 24),
                  Text(
                    'Статус онлайн',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSwitchOption(
                    theme,
                    'Показывать статус онлайн',
                    'Другие пользователи будут видеть, когда вы в сети',
                    _showOnlineStatus,
                    (value) => setState(() => _showOnlineStatus = value),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarVisibilityOption(AppTheme theme, String value, String title, String description) {
    final isSelected = _avatarVisibility == value;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.bubbleColorOther.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? theme.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _avatarVisibility,
        onChanged: (val) => setState(() => _avatarVisibility = val ?? 'all'),
        title: Text(
          title,
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          description,
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
        ),
        activeColor: theme.primaryColor,
      ),
    );
  }

  Widget _buildSwitchOption(AppTheme theme, String title, String description, bool value, ValueChanged<bool> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bubbleColorOther.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          description,
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
        ),
        activeColor: theme.primaryColor,
      ),
    );
  }

  Widget _buildExceptionsList(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bubbleColorOther.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Выберите пользователей',
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Функция будет реализована позже',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _userService.dispose();
    super.dispose();
  }
}

