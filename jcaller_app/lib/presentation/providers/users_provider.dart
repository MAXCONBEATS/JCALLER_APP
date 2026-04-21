import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:jcaller_app/core/network/api_client.dart';
import 'package:jcaller_app/presentation/providers/auth_provider.dart';

part 'users_provider.g.dart';

@riverpod
Future<List<Map<String, dynamic>>> usersList(UsersListRef ref) async {
  final token = await ref.watch(authNotifierProvider.future);
  if (token == null) throw Exception('Not authenticated');
  final api = await ref.watch(apiClientProvider.future);
  final response = await api.get('/api/users', token: token);
  // response уже является списком
  return List<Map<String, dynamic>>.from(response);
}