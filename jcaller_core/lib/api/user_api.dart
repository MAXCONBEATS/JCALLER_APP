import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:jcaller_core/models/user.dart';
import 'package:jcaller_core/repositories/users_repository.dart';
import 'package:jcaller_core/services/auth_service.dart';

class UserApi {
  final UsersRepository repository;
  final String host;
  final int port;

  UserApi(this.repository, {this.host = '0.0.0.0', this.port = 8081});

  Future<void> run() async {
    final server = await HttpServer.bind(host, port);
    await repository.init();

    developer
        .log('UserApi running on http://${server.address.host}:${server.port}');
    print('✅ User API running on http://localhost:${server.port}');

    await for (final request in server) {
      try {
        await _handleRequest(request);
      } catch (e) {
        developer.log('Error handling request: $e');
        // Здесь ответ уже закрыт внутри обработчиков, но если ошибка случилась до закрытия,
        // нужно отправить ошибку и закрыть.
        try {
          await _sendJsonResponse(request.response,
              statusCode: HttpStatus.internalServerError,
              data: {'error': 'Internal server error'});
        } catch (_) {}
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Добавьте эту строку в начало метода
    print('📨 Received: ${request.method} ${request.requestedUri.path}');

    // CORS preflight
    if (request.method == 'OPTIONS') {
      print('  → OPTIONS request, sending CORS');
      await _sendCorsResponse(request.response);
      return;
    }

    // Добавляем CORS заголовки
    request.response.headers.set('Access-Control-Allow-Origin', '*');

    final path = request.requestedUri.path;
    print('  → Path: $path');
    if (path == '/docs' && request.method == 'GET') {
      await _handleSwaggerUI(request);
      return;
    }
    if (path == '/swagger.yaml' && request.method == 'GET') {
      await _handleSwaggerYaml(request);
      return;
    }

    // Публичные endpoints (не требуют авторизации)
    if (path == '/api/auth/register' && request.method == 'POST') {
      print('  → Register endpoint matched');
      await _register(request);
    } else if (path == '/api/auth/login' && request.method == 'POST') {
      print('  → Login endpoint matched');
      await _login(request);
    }
    // Health check
    else if (path == '/health' && request.method == 'GET') {
      print('  → Health endpoint matched');
      await _health(request);
    }
    // Защищенные endpoints
    else {
      print('  → No endpoint matched, checking auth...');
      // Проверяем токен
      final userId = await _authenticateRequest(request);
      if (userId == null) {
        await _sendJsonResponse(request.response,
            statusCode: HttpStatus.unauthorized,
            data: {'error': 'Unauthorized'});
        return;
      }

      if (path == '/api/users' && request.method == 'GET') {
        await _getAllUsers(request);
      } else if (path.startsWith('/api/users/') && request.method == 'GET') {
        await _getUserById(request);
      } else {
        await _sendJsonResponse(request.response,
            statusCode: HttpStatus.notFound, data: {'error': 'Not found'});
      }
    }
  }

  Future<String?> _authenticateRequest(HttpRequest request) async {
    final authHeader = request.headers.value('authorization');

    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }

    final token = authHeader.substring(7);
    return AuthService.getUserIdFromToken(token);
  }

  Future<void> _health(HttpRequest request) async {
    await _sendJsonResponse(request.response, data: {'status': 'healthy'});
  }

  Future<void> _register(HttpRequest request) async {
    print('📝 _register called');

    try {
      // Прочитаем тело запроса
      final payload = await utf8.decodeStream(request);
      print('📦 Raw payload: "$payload"');

      if (payload.isEmpty) {
        print('❌ Empty payload');
        await _sendJsonResponse(request.response,
            statusCode: HttpStatus.badRequest,
            data: {'error': 'Empty request body'});
        return;
      }

      // Попробуем распарсить JSON
      Map<String, dynamic> json;
      try {
        json = jsonDecode(payload);
        print('✅ Parsed JSON: $json');
      } catch (e) {
        print('❌ JSON parse error: $e');
        await _sendJsonResponse(request.response,
            statusCode: HttpStatus.badRequest,
            data: {'error': 'Invalid JSON: $e'});
        return;
      }

      // Проверим наличие полей
      final username = json['username'];
      final password = json['password'];

      print('📝 Username: $username, Password length: ${password?.length}');

      if (username == null || password == null) {
        print('❌ Missing fields');
        await _sendJsonResponse(request.response,
            statusCode: HttpStatus.badRequest,
            data: {'error': 'Missing username or password'});
        return;
      }

      // Валидация
      if (username.toString().length < 3) {
        print('❌ Username too short');
        await _sendJsonResponse(request.response,
            statusCode: HttpStatus.badRequest,
            data: {'error': 'Username must be at least 3 characters'});
        return;
      }

      if (password.toString().length < 6) {
        print('❌ Password too short');
        await _sendJsonResponse(request.response,
            statusCode: HttpStatus.badRequest,
            data: {'error': 'Password must be at least 6 characters'});
        return;
      }

      print('✅ Validation passed, creating user...');

      // Создаем пользователя
      final user =
          await repository.createUser(username.toString(), password.toString());
      print('✅ User created: ${user.id}');

      // Не отправляем пароль
      final userJson = user.toJson();
      userJson.remove('password');

      print('📤 Sending response: $userJson');
      await _sendJsonResponse(request.response, data: userJson);
    } catch (e, stackTrace) {
      print('❌ Register error: $e');
      print('Stack trace: $stackTrace');
      await _sendJsonResponse(request.response,
          statusCode: HttpStatus.badRequest, data: {'error': e.toString()});
    }
  }

  Future<void> _login(HttpRequest request) async {
    try {
      final payload = await utf8.decodeStream(request);
      developer.log('Login payload: $payload');

      final json = jsonDecode(payload);

      final username = json['username'] as String;
      final password = json['password'] as String;

      final user = await repository.authenticate(username, password);

      if (user == null) {
        await _sendJsonResponse(request.response,
            statusCode: HttpStatus.unauthorized,
            data: {'error': 'Invalid username or password'});
        return;
      }

      // Генерируем токен
      final token = AuthService.generateToken(user);

      final userJson = user.toJson();
      userJson.remove('password');

      await _sendJsonResponse(request.response, data: {
        'user': userJson,
        'token': token,
      });
    } catch (e) {
      developer.log('Login error: $e');
      await _sendJsonResponse(request.response,
          statusCode: HttpStatus.badRequest, data: {'error': e.toString()});
    }
  }

  Future<void> _getAllUsers(HttpRequest request) async {
    final users = await repository.getUsers();
    final usersJson = users.map((u) {
      final json = u.toJson();
      json.remove('password');
      return json;
    }).toList();

    await _sendJsonResponse(request.response, data: usersJson);
  }

  Future<void> _getUserById(HttpRequest request) async {
    final id = request.requestedUri.pathSegments.last;
    final user = await repository.getUser(id);

    if (user == null) {
      await _sendJsonResponse(request.response,
          statusCode: HttpStatus.notFound, data: {'error': 'User not found'});
      return;
    }

    final userJson = user.toJson();
    userJson.remove('password');

    await _sendJsonResponse(request.response, data: userJson);
  }

  Future<void> _sendJsonResponse(HttpResponse response,
      {int statusCode = HttpStatus.ok, required dynamic data}) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
  }

  Future<void> _sendCorsResponse(HttpResponse response) async {
    response
      ..statusCode = HttpStatus.ok
      ..headers.set('Access-Control-Allow-Origin', '*')
      ..headers.set(
          'Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
      ..headers.set('Access-Control-Allow-Headers',
          'Origin, Content-Type, Authorization');
  }

  Future<void> _handleSwaggerUI(HttpRequest request) async {
    final html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>JCaller API Docs</title>
  <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.10.5/swagger-ui.css" />
  <script src="https://unpkg.com/swagger-ui-dist@5.10.5/swagger-ui-bundle.js"></script>
</head>
<body>
<div id="swagger-ui"></div>
<script>
  window.onload = () => {
    SwaggerUIBundle({
      url: "/swagger.yaml",
      dom_id: '#swagger-ui',
      presets: [SwaggerUIBundle.presets.apis],
      layout: "BaseLayout",
    });
  };
</script>
</body>
</html>
  ''';
    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    await request.response.close();
  }

  Future<void> _handleSwaggerYaml(HttpRequest request) async {
    try {
      final currentDir = Directory.current.path;
      final yamlPath = '$currentDir/specs/swagger.yaml';
      final file = File(yamlPath);

      print('🔍 Looking for swagger.yaml at: $yamlPath');

      if (!await file.exists()) {
        print('❌ File not found');
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('swagger.yaml not found');
        await request.response.close();
        return;
      }

      final content = await file.readAsString();
      print('✅ File read, size: ${content.length} bytes');
      // Устанавливаем кодировку UTF-8 для ответа
      request.response.headers
          .set('Content-Type', 'application/x-yaml; charset=utf-8');
      // Используем write() с преобразованием в байты UTF-8
      final bytes = utf8.encode(content);
      request.response.add(bytes);
      await request.response.close();
    } catch (e, stack) {
      print('❌ Error reading swagger.yaml: $e');
      print(stack);
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Error: $e');
        await request.response.close();
      } catch (_) {}
    }
  }
}
