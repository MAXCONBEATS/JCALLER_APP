import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:jcaller_core/models/user.dart';

class AuthService {
  static const String _secretKey = 'your-secret-key-change-in-production'; 
  static const int _tokenExpirationHours = 24;
  
  // Хеширование пароля
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Проверка пароля
  static bool verifyPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }
  
  // Генерация JWT токена - ИСПРАВЛЕНО
  static String generateToken(User user) {
    final payload = {
      'userId': user.id,
      'username': user.username,
      'exp': DateTime.now()
          .add(Duration(hours: _tokenExpirationHours))
          .millisecondsSinceEpoch ~/ 1000,
    };
    
    final jwt = JWT(payload, issuer: 'jcaller');
    return jwt.sign(SecretKey(_secretKey));
  }
  
  // Проверка и декодирование токена
  static Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_secretKey));
      return jwt.payload as Map<String, dynamic>;
    } on JWTExpiredException {
      print('JWT expired');
      return null;
    } on JWTException catch (e) {
      print('JWT invalid: $e');
      return null;
    } catch (e) {
      print('Error verifying token: $e');
      return null;
    }
  }
  
  // Извлечение userId из токена
  static String? getUserIdFromToken(String token) {
    final payload = verifyToken(token);
    return payload?['userId'];
  }
  
  // Проверка токена
  static bool isTokenValid(String token) {
    return verifyToken(token) != null;
  }
  
  // Получение времени истечения
  static DateTime? getTokenExpiration(String token) {
    final payload = verifyToken(token);
    if (payload == null) return null;
    
    final exp = payload['exp'] as int?;
    if (exp == null) return null;
    
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  }
}