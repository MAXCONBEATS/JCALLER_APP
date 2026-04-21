import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:jcaller_app/core/models/user.dart';   // правильный импорт
import 'package:jcaller_app/presentation/providers/auth_provider.dart';

part 'current_user_provider.g.dart';

@riverpod
Future<User> currentUser(CurrentUserRef ref) async {
  final token = await ref.watch(authNotifierProvider.future);
  if (token == null) throw Exception('Not authenticated');

  // Декодируем JWT
  final parts = token.split('.');
  if (parts.length != 3) throw Exception('Invalid token');
  final payload = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
  );
  final userId = payload['userId'] as String?;
  final username = payload['username'] as String?;
  if (userId == null || username == null) throw Exception('Missing user data in token');
  return User(id: userId, username: username, createdAt: DateTime.now());
}