import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/theme_service.dart';
import '../models/app_theme.dart';
import 'login_screen.dart';
import 'privacy_settings_screen.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _userService = UserService();
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = themeService.currentTheme;

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
            _buildSettingItem(
              theme: theme,
              icon: Icons.lock_outline,
              title: 'Сменить пароль',
              onTap: () {
                _showChangePasswordDialog(theme);
              },
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              theme: theme,
              icon: Icons.phone,
              title: 'Сменить номер телефона',
              onTap: () {
                _showChangePhoneDialog(theme);
              },
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              theme: theme,
              icon: Icons.block,
              title: 'Черный список',
              subtitle: 'Заблокированные пользователи',
              onTap: () {
              },
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              theme: theme,
              icon: Icons.privacy_tip,
              title: 'Конфиденциальность',
              subtitle: 'Видимость аватара и статусы',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacySettingsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildSettingItem(
              theme: theme,
              icon: Icons.delete_forever,
              title: 'Удалить аккаунт',
              textColor: Colors.red,
              onTap: () {
                _showDeleteAccountDialog(theme);
              },
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
                            fontSize: 14,
                          ),
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

  void _showChangePasswordDialog(AppTheme theme) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureOldPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

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
                              Icons.lock_outline,
                              color: theme.primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Сменить пароль',
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
                        controller: oldPasswordController,
                        obscureText: obscureOldPassword,
                        style: TextStyle(color: theme.textColor),
                        decoration: InputDecoration(
                          labelText: 'Текущий пароль',
                          labelStyle: TextStyle(color: theme.secondaryTextColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureOldPassword ? Icons.visibility : Icons.visibility_off,
                              color: theme.secondaryTextColor,
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                obscureOldPassword = !obscureOldPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: newPasswordController,
                        obscureText: obscureNewPassword,
                        style: TextStyle(color: theme.textColor),
                        decoration: InputDecoration(
                          labelText: 'Новый пароль',
                          labelStyle: TextStyle(color: theme.secondaryTextColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                              color: theme.secondaryTextColor,
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                obscureNewPassword = !obscureNewPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        style: TextStyle(color: theme.textColor),
                        decoration: InputDecoration(
                          labelText: 'Подтвердите новый пароль',
                          labelStyle: TextStyle(color: theme.secondaryTextColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                              color: theme.secondaryTextColor,
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                obscureConfirmPassword = !obscureConfirmPassword;
                              });
                            },
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
                          ElevatedButton(
                            onPressed: () async {
                              if (newPasswordController.text != confirmPasswordController.text) {
                                return;
                              }
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
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
        ),
      ),
    );
  }

  void _showChangePhoneDialog(AppTheme theme) {
    final phoneController = TextEditingController();
    
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
                          Icons.phone,
                          color: theme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Сменить номер телефона',
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
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: theme.textColor),
                    decoration: InputDecoration(
                      labelText: 'Новый номер телефона',
                      labelStyle: TextStyle(color: theme.secondaryTextColor),
                      hintText: '+7 (999) 123-45-67',
                      hintStyle: TextStyle(color: theme.secondaryTextColor),
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
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
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


  void _showDeleteAccountDialog(AppTheme theme) {
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
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Удалить аккаунт?',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Это действие нельзя отменить. Все ваши данные будут удалены.',
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
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
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: theme.backgroundColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const CircularProgressIndicator(),
                              ),
                            ),
                          );
                          
                          try {
                            final result = await _userService.deleteAccount();
                            
                            if (!mounted) return;
                            
                            Navigator.pop(context);
                            if (result['success'] == true) {
                              await _authService.logout();
                              if (mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                  (route) => false,
                                );
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result['error'] ?? 'Ошибка при удалении аккаунта',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (!mounted) return;
                            Navigator.pop(context); 
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Ошибка: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
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
    );
  }

  @override
  void dispose() {
    _userService.dispose();
    super.dispose();
  }
}

