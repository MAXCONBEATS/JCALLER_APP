import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:jcaller_app/core/network/api_client.dart';
import 'package:jcaller_app/data/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

part 'auth_provider.g.dart';
// Глобальный доступ к navigatorKey (можно поместить в отдельный файл)
final rootNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
Future<ApiClient> apiClient(ApiClientRef ref) async {
  return ApiClient(baseUrl: 'http://localhost:8081');
}

@riverpod
Future<AuthService> authService(AuthServiceRef ref) async {
  final apiClient = await ref.watch(apiClientProvider.future);
  return AuthService(apiClient);
}

@riverpod
class AuthNotifier extends _$AuthNotifier {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    try {
      final service = await ref.read(authServiceProvider.future);
      final response = await service.login(username, password);
      final token = response['token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      state = AsyncData(token);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> logout({bool showMessage = true}) async {
    if (showMessage) {
      _showSnackBar('Сессия завершена. Пожалуйста, войдите снова.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    state = const AsyncData(null);
    // Перенаправляем на главный экран (логин)
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _showSnackBar(String message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

