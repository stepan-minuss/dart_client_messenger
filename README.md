# Messenger Client

Flutter клиентское приложение для мессенджера с поддержкой End-to-End Encryption (E2EE).

## Технологии

- **Flutter** - кроссплатформенный фреймворк
- **Provider** - управление состоянием
- **Socket.IO Client** - WebSocket для real-time коммуникации
- **Flutter Secure Storage** - безопасное хранение токенов и ключей
- **Encrypt** - шифрование сообщений
- **SQLite** - локальное кеширование сообщений

## Установка

1. Убедитесь, что у вас установлен Flutter SDK (>=3.0.0)

2. Установите зависимости:
```bash
flutter pub get
```

3. Настройте базовый URL сервера в `lib/utils/constants.dart`

4. Запустите приложение:
```bash
flutter run
```

## Структура проекта

### Основные директории

- `lib/main.dart` - точка входа приложения
- `lib/screens/` - экраны приложения
- `lib/services/` - сервисы для работы с API и Socket.IO
- `lib/widgets/` - переиспользуемые виджеты
- `lib/utils/` - утилиты и константы
- `lib/models/` - модели данных

### Сервисы

- `auth_service.dart` - аутентификация и авторизация
- `socket_service.dart` - работа с Socket.IO
- `security_service.dart` - генерация ключей и шифрование
- `theme_service.dart` - управление темами
- `user_service.dart` - работа с пользователями
- `notification_service.dart` - уведомления
- `message_cache_service.dart` - кеширование сообщений
- `contact_cache_service.dart` - кеширование контактов
- `active_chats_cache_service.dart` - кеширование активных чатов

### Экраны

- `auth_check.dart` - проверка аутентификации
- `login_screen.dart` - экран входа
- `register_screen.dart` - экран регистрации
- `home_screen.dart` - главный экран с чатами
- `chat_screen.dart` - экран чата
- `contacts_screen.dart` - экран контактов
- `user_search_screen.dart` - поиск пользователей
- `user_profile_screen.dart` - профиль пользователя
- `settings_screen.dart` - настройки
- `profile_settings_screen.dart` - настройки профиля
- `security_settings_screen.dart` - настройки безопасности
- `privacy_settings_screen.dart` - настройки приватности
- `theme_customization_screen.dart` - кастомизация темы
- `theme_editor_screen.dart` - редактор темы
- `image_viewer_screen.dart` - просмотр изображений

## Основные функции

- Регистрация и вход пользователей
- Отправка и получение сообщений в реальном времени
- End-to-End Encryption для сообщений
- Отправка изображений
- Ответы на сообщения
- Статус печати
- Прочитанные сообщения
- Кастомизация тем
- Настройки приватности
- Локальные имена контактов
- Уведомления о новых сообщениях
- Кеширование данных для офлайн работы

## Конфигурация

Настройте базовый URL сервера в `lib/utils/constants.dart`:

```dart
class AppConstants {
  static const String baseUrl = 'http://your-server-url';
  // ...
}
```

## Сборка

### Android
```bash
flutter build apk
```

### iOS
```bash
flutter build ios
```

### Web
```bash
flutter build web
```


