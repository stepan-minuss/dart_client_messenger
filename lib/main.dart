import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/theme_service.dart';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'screens/auth_check.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await NotificationService.initialize();
  
  NotificationService.onNotificationTapped = (response) async {
    if (response.payload != null) {
      final parts = response.payload!.split(',');
      if (parts.length >= 2) {
        final senderId = int.tryParse(parts[0]);
        final messageId = int.tryParse(parts[1]);
        
        if (senderId != null && navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatUserId: senderId,
                chatUsername: 'Пользователь',
                initialReplyToMessageId: messageId,
              ),
            ),
          );
        }
      } else {
        final senderId = int.tryParse(response.payload!);
        if (senderId != null && navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatUserId: senderId,
                chatUsername: 'Пользователь',
              ),
            ),
          );
        }
      }
    }
  };
  
  runApp(const MessengerApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MessengerApp extends StatelessWidget {
  const MessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        Provider(create: (_) => SocketService(), dispose: (_, service) => service.dispose()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Nebula',
            debugShowCheckedModeBanner: false,
            
            locale: const Locale('ru'),
            
            theme: themeService.currentTheme.toThemeData().copyWith(
              textTheme: GoogleFonts.robotoTextTheme(
                themeService.currentTheme.toThemeData().textTheme,
              ),
            ),
            
            home: const AuthCheck(),
            
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/home': (context) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}


