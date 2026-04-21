# JCaller Core – сервер для VoIP звонков

Серверная часть приложения для аудио/видеозвонков в локальной сети.  
Реализует REST API для управления пользователями и звонками, WebSocket для WebRTC сигналинга, хранилище SQLite.

## 📋 Возможности

- Регистрация и аутентификация пользователей (JWT токены)
- Хранение пользователей, запросов на звонок и сессий в SQLite
- REST API для управления:
  - регистрация / логин
  - получение списка пользователей
  - создание / принятие / отклонение / завершение звонков
- WebSocket сервер для обмена сигнальными сообщениями (offer, answer, ice-candidate)
- Swagger UI для тестирования API (доступен по адресу `/docs`)
- Кроссплатформенность (Windows / Linux / macOS)

## 🚀 Быстрый старт

### Требования

- Dart SDK >= 3.0.0
- SQLite3 (библиотека `sqlite3.dll` на Windows или `libsqlite3.so` на Linux)

### Установка

1. Клонируйте репозиторий (или просто скопируйте папку `jcaller_core`).
2. Перейдите в папку проекта:
   ```bash
   cd jcaller_core
#### Установите зависимости:

    ```bash
    dart pub get
#### Скачайте SQLite3 библиотеку для вашей ОС:

Windows: скачайте sqlite3.dll с официального сайта и положите в корень проекта.

Linux: установите через пакетный менеджер (sudo apt install libsqlite3-dev).

macOS: уже установлена.

#### Запуск
bash
dart run bin/server.dart
После запуска сервер будет доступен:

REST API (User API): http://localhost:8081

WebSocket сигналинг: ws://localhost:8080/ws/signal

Swagger UI: http://localhost:8081/docs

## 📚 API Документация
Аутентификация
Большинство эндпоинтов требуют JWT токен, полученный при логине.
Токен передаётся в заголовке: Authorization: Bearer <token>

### Основные эндпоинты
Метод	URL	Описание
POST	/api/auth/register	Регистрация пользователя
POST	/api/auth/login	Логин, возвращает JWT токен
GET	/api/users	Список всех пользователей
GET	/api/users/{id}	Данные конкретного пользователя
POST	/api/calls/request	Создать запрос на звонок
GET	/api/calls/requests/{userId}	Получить входящие запросы
POST	/api/calls/accept/{requestId}	Принять звонок
POST	/api/calls/reject/{requestId}	Отклонить звонок
POST	/api/calls/end/{sessionId}	Завершить активный звонок
GET	/health	Проверка состояния
### Примеры запросов
Регистрация
bash
curl -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "123456"}'
Логин
bash
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "123456"}'
Ответ:

json
{
  "user": { "id": "...", "username": "alice", "createdAt": "..." },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
Получение списка пользователей (с токеном)
bash
curl -X GET http://localhost:8081/api/users \
  -H "Authorization: Bearer <ваш_токен>"
Создание запроса на звонок
bash
curl -X POST http://localhost:8081/api/calls/request \
  -H "Authorization: Bearer <токен>" \
  -H "Content-Type: application/json" \
  -d '{"senderId": "alice_id", "recipientId": "bob_id"}'
## 🔌 WebSocket сигналинг
После установки WebSocket соединения (ws://localhost:8080/ws/signal) клиент должен отправить сообщение register:

json
{
  "type": "register",
  "userId": "alice_id"
}
Далее можно обмениваться сигнальными сообщениями:

offer – инициация звонка

answer – ответ на звонок

ice-candidate – ICE кандидаты

Пример сообщения offer:

json
{
  "type": "offer",
  "targetId": "bob_id",
  "offer": {
    "sdp": "v=0\r\no=- ...",
    "type": "offer"
  }
}
Сервер пересылает сообщения целевому пользователю (если он онлайн).

## 🧪 Тестирование
Для быстрой проверки работы API можно использовать Swagger UI:

Откройте в браузере http://localhost:8081/docs

Нажмите "Authorize" и вставьте JWT токен (полученный при логине)

Выполняйте любые запросы прямо из интерфейса

## 🗄️ База данных
Файл базы данных: jcaller.db (создаётся автоматически в корне проекта)

Таблицы: users, call_requests, calling_sessions

Для просмотра можно использовать SQLite Browser

🛠️ Разработка и сборка
Генерация JSON-сериализации
Если вы изменили модели данных, перегенерируйте .g.dart файлы:

bash
dart run build_runner build
Запуск в режиме отладки
bash
dart run bin/server.dart
Логи выводятся в консоль. Для остановки сервера нажмите Ctrl+C.

## 📦 Структура проекта
text
jcaller_core/
├── bin/
│   └── server.dart              # Точка входа
├── lib/
│   ├── api/
│   │   └── user_api.dart        # REST API (порт 8081)
│   ├── models/                  # Модели данных (User, CallRequest, CallingSession)
│   ├── repositories/            # Репозитории (SQLite)
│   ├── server/
│   │   └── jcaller_server.dart  # WebRTC сервер + WebSocket (порт 8080)
│   └── services/
│       ├── auth_service.dart    # JWT и хеширование паролей
│       └── webrtc_signal_service.dart
├── specs/
│   └── swagger.yaml             # OpenAPI спецификация
├── sqlite3.dll                  # (Windows) библиотека SQLite
├── pubspec.yaml
└── README.md
## 📄 Лицензия
MIT

JCaller Core – простой и надёжный бэкенд для VoIP приложений.
Приятной разработки! 🚀