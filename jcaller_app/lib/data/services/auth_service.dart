import 'package:jcaller_app/core/network/api_client.dart';

class AuthService {
  final ApiClient _client;

  AuthService(this._client);

  Future<Map<String, dynamic>> register(String username, String password) async {
    return await _client.post('/api/auth/register', {
      'username': username,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    return await _client.post('/api/auth/login', {
      'username': username,
      'password': password,
    });
  }
}