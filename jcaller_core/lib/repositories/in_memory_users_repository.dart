import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:crypto/crypto.dart';
import 'package:jcaller_core/models/user.dart';
import 'package:jcaller_core/repositories/users_repository.dart';

class InMemoryUsersRepository implements UsersRepository {
  final Map<String, User> _users = {};
  final Map<String, String> _usernameToId = {};
  bool _initialized = false;
  @override
  Future<void> init() async {
    if (_initialized) return;
    developer.log('UsersRepository initialized');
    final existingUser = await getUserByUsername('test_user');
    if (existingUser == null) {
      await createUser('test_user', 'password123');
    }
    
    _initialized = true;
  }
  
  @override
  Future<void> dispose() async {
    _users.clear();
    _usernameToId.clear();
    developer.log('UsersRepository disposed');
  }
  
  @override
  Future<List<User>> getUsers() async {
    return _users.values.toList();
  }
  
  @override
  Future<User?> getUser(String id) async {
    return _users[id];
  }
  
  @override
  Future<User?> getUserByUsername(String username) async {
    final id = _usernameToId[username.toLowerCase()];
    return id != null ? _users[id] : null;
  }
  
  @override
  Future<User> createUser(String username, String password) async {
    final existing = await getUserByUsername(username);
    if (existing != null) {
      throw Exception('Username already taken');
    }
    
    // ИСПРАВЛЕНО: используем метод из AuthService
    final passwordHash = hashPassword(password);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final user = User(
      id: id,
      username: username,
      password: passwordHash,
      createdAt: DateTime.now(),
    );
    
    _users[user.id] = user;
    _usernameToId[username.toLowerCase()] = user.id;
    
    return user;
  }
  
  @override
  Future<User?> authenticate(String username, String password) async {
    final user = await getUserByUsername(username);
    if (user == null) return null;
    
    // ИСПРАВЛЕНО: используем метод из AuthService
    if (verifyPassword(password, user.password)) {
      return user;
    }
    
    return null;
  }
  
  // ИСПРАВЛЕНО: выносим методы хеширования в отдельные функции
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  bool verifyPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }
  
  @override
  Future<void> deleteUser(String id) async {
    final user = _users[id];
    if (user != null) {
      _usernameToId.remove(user.username.toLowerCase());
      _users.remove(id);
    }
  }
  
  @override
  Future<User> updateUser(String id, User user) async {
    if (!_users.containsKey(id)) {
      throw Exception('User not found');
    }
    
    final oldUser = _users[id]!;
    if (oldUser.username != user.username) {
      _usernameToId.remove(oldUser.username.toLowerCase());
      _usernameToId[user.username.toLowerCase()] = id;
    }
    
    _users[id] = user;
    return user;
  }
}