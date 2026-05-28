# JCaller App

Flutter-клиент для голосовых звонков в локальной сети.  
Приложение авторизует пользователя, показывает список контактов и онлайн-статус, устанавливает соединение через WebSocket-сигналинг и передает аудио через WebRTC.

## Платформы

- Android (эмулятор и реальное устройство)
- Windows (десктоп-клиент)

## Использованные библиотеки

- `flutter_webrtc` — создание P2P-звонка и передача аудио
- `web_socket_channel` — WebSocket-сигналинг с сервером
- `http` — REST-запросы (логин, список пользователей и т.д.)
- `flutter_riverpod`, `riverpod`, `riverpod_annotation` — управление состоянием
- `permission_handler` — запрос доступа к микрофону
- `shared_preferences` — локальное хранение токена

## Основные файлы

- `lib/main.dart` — точка входа, запрос разрешений, маршруты экранов
- `lib/core/config/server_config.dart` — адреса API и WebSocket сервера
- `lib/data/services/auth_service.dart` — запросы регистрации/логина
- `lib/data/services/websocket_service.dart` — WebSocket подключение и обмен сигналами
- `lib/webrtc/call_manager.dart` — логика звонка, WebRTC peer connection и аудио-треки
- `lib/presentation/screens/home_screen.dart` — список пользователей, онлайн-статусы, запуск звонка
- `lib/presentation/screens/call_screen.dart` — экран активного звонка
- `lib/presentation/providers/signaling_provider.dart` — обработка входящих сигналов и синхронизация online users
- `lib/presentation/providers/call_provider.dart` — состояние и управление `CallManager`

## Краткий запуск

```bash
flutter pub get
flutter run
```

Перед запуском проверь `lib/core/config/server_config.dart`: там должен быть корректный IP/host сервера для твоего устройства.
