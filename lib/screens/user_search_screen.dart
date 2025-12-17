import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/user_service.dart';
import '../services/theme_service.dart';
import '../models/app_theme.dart';
import '../widgets/avatar_with_frame.dart';
import 'user_profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _searchController = TextEditingController();
  final _userService = UserService();
  List<User> _searchResults = [];
  bool _isLoading = false;
  
  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final results = await _userService.searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
        backgroundColor: theme.backgroundColor,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: theme.textColor),
          decoration: InputDecoration(
            hintText: 'Поиск пользователей...',
            hintStyle: TextStyle(color: theme.secondaryTextColor),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (value == _searchController.text) {
                _search(value);
              }
            });
          },
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : _searchResults.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'Введите имя для поиска'
                        : 'Никого не найдено',
                    style: TextStyle(color: theme.secondaryTextColor),
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      leading: SizedBox(
                        width: 40,
                        height: 40,
                        child: AvatarWithFrame(
                          user: user,
                          radius: 20,
                          backgroundColor: theme.primaryColor.withOpacity(0.2),
                          textStyle: TextStyle(color: theme.primaryColor),
                        ),
                      ),
                      title: Text(
                        (user.username.isNotEmpty) 
                            ? user.username 
                            : '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim().isEmpty
                                ? 'Пользователь'
                                : '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim(),
                        style: TextStyle(color: theme.textColor),
                      ),
                      subtitle: (user.username.isNotEmpty && (user.firstName != null || user.lastName != null)) ||
                                (user.username.isEmpty && (user.firstName != null || user.lastName != null))
                          ? Text(
                              '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim(),
                              style: TextStyle(color: theme.secondaryTextColor),
                            )
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: user.id,
                              username: user.username,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}


