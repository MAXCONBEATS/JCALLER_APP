import 'dart:async';
import 'dart:developer' as developer;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/open.dart';
import 'package:jcaller_core/models/user.dart';
import 'package:jcaller_core/repositories/users_repository.dart';
import 'package:jcaller_core/services/auth_service.dart';

class SqliteUsersRepository implements UsersRepository {
  static const String _dbName = 'jcaller.db';
  Database? _db;
  bool _initialized = false;
  
  @override
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      // Открываем базу данных
      _db = sqlite3.open(_dbName);
      
      // Создаем таблицы
      _createTables();
      
      _initialized = true;
      developer.log('SQLite Repository initialized successfully');
      print('✅ SQLite database ready at: ${Uri.file(_dbName).toFilePath()}');
      
    } catch (e, stackTrace) {
      developer.log('Failed to initialize SQLite repository', error: e, stackTrace: stackTrace);
      print('❌ Failed to initialize database: $e');
      rethrow;
    }
  }
  
  void _createTables() {
    // Таблица пользователей
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        lastLogin TEXT,
        isOnline INTEGER DEFAULT 0
      )
    ''');
    
    // Индекс для поиска по username
    _db!.execute('CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)');
    
    // Таблица запросов на звонок
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS call_requests (
        id TEXT PRIMARY KEY,
        senderId TEXT NOT NULL,
        recipientId TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    
    // Индексы для запросов
    _db!.execute('CREATE INDEX IF NOT EXISTS idx_call_requests_sender ON call_requests(senderId)');
    _db!.execute('CREATE INDEX IF NOT EXISTS idx_call_requests_recipient ON call_requests(recipientId)');
    
    // Таблица сессий звонков
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS calling_sessions (
        id TEXT PRIMARY KEY,
        callerId TEXT NOT NULL,
        recipientId TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        durationSeconds INTEGER DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'ringing'
      )
    ''');
    
    // Индексы для сессий
    _db!.execute('CREATE INDEX IF NOT EXISTS idx_calling_sessions_caller ON calling_sessions(callerId)');
    _db!.execute('CREATE INDEX IF NOT EXISTS idx_calling_sessions_recipient ON calling_sessions(recipientId)');
    
    // Добавляем тестового пользователя (пароль: admin)
    _db!.execute('''
      INSERT OR IGNORE INTO users (id, username, password, createdAt) 
      VALUES ('1', 'admin', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', datetime('now'))
    ''');
    
    developer.log('Database tables created successfully');
  }
  
  @override
  Future<void> dispose() async {
    _db?.dispose();
    _initialized = false;
    developer.log('SQLite Repository disposed');
  }
  
  @override
  Future<List<User>> getUsers() async {
    final result = _db!.select('SELECT id, username, password, createdAt FROM users ORDER BY createdAt DESC');
    
    return result.map((row) {
      return User(
        id: row['id'] as String,
        username: row['username'] as String,
        password: row['password'] as String,
        createdAt: DateTime.parse(row['createdAt'] as String),
      );
    }).toList();
  }
  
  @override
  Future<User?> getUser(String id) async {
    final result = _db!.select('SELECT id, username, password, createdAt FROM users WHERE id = ?', [id]);
    
    if (result.isEmpty) return null;
    
    final row = result.first;
    return User(
      id: row['id'] as String,
      username: row['username'] as String,
      password: row['password'] as String,
      createdAt: DateTime.parse(row['createdAt'] as String),
    );
  }
  
  @override
  Future<User?> getUserByUsername(String username) async {
    final result = _db!.select('SELECT id, username, password, createdAt FROM users WHERE username = ?', [username.toLowerCase()]);
    
    if (result.isEmpty) return null;
    
    final row = result.first;
    return User(
      id: row['id'] as String,
      username: row['username'] as String,
      password: row['password'] as String,
      createdAt: DateTime.parse(row['createdAt'] as String),
    );
  }
  
  @override
  Future<User> createUser(String username, String password) async {
    // Проверяем, не занят ли username
    final existing = await getUserByUsername(username);
    if (existing != null) {
      throw Exception('Username already taken');
    }
    
    final passwordHash = AuthService.hashPassword(password);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now().toIso8601String();
    
    _db!.execute(
      'INSERT INTO users (id, username, password, createdAt) VALUES (?, ?, ?, ?)',
      [id, username.toLowerCase(), passwordHash, now]
    );
    
    return User(
      id: id,
      username: username,
      password: passwordHash,
      createdAt: DateTime.parse(now),
    );
  }
  
  @override
  Future<User?> authenticate(String username, String password) async {
    final user = await getUserByUsername(username);
    if (user == null) return null;
    
    if (AuthService.verifyPassword(password, user.password)) {
      // Обновляем время последнего входа и онлайн статус
      _db!.execute(
        'UPDATE users SET lastLogin = ?, isOnline = 1 WHERE id = ?',
        [DateTime.now().toIso8601String(), user.id]
      );
      return user;
    }
    
    return null;
  }
  
  @override
  Future<void> deleteUser(String id) async {
    _db!.execute('DELETE FROM users WHERE id = ?', [id]);
  }
  
  @override
  Future<User> updateUser(String id, User user) async {
    _db!.execute(
      'UPDATE users SET username = ?, password = ? WHERE id = ?',
      [user.username.toLowerCase(), user.password, id]
    );
    return user;
  }
  
  // Дополнительные методы
  Future<void> setUserOnline(String userId, bool online) async {
    if (online) {
      _db!.execute(
        'UPDATE users SET isOnline = 1, lastLogin = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), userId]
      );
    } else {
      _db!.execute('UPDATE users SET isOnline = 0 WHERE id = ?', [userId]);
    }
  }
  
  Future<List<User>> getOnlineUsers() async {
    final result = _db!.select('SELECT id, username, createdAt FROM users WHERE isOnline = 1');
    
    return result.map((row) {
      return User(
        id: row['id'] as String,
        username: row['username'] as String,
        password: '',
        createdAt: DateTime.parse(row['createdAt'] as String),
      );
    }).toList();
  }
}